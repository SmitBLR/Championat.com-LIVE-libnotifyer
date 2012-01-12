import javax.swing.ListSelectionModel
import javax.swing.JFrame
import javax.swing.JPanel
import javax.swing.JButton
import javax.swing.JList
import javax.swing.JEditorPane
import javax.swing.JScrollPane
import javax.swing.JSplitPane
import javax.swing.JLabel
import javax.swing.JCheckBox
import javax.swing.DefaultListModel
import javax.swing.ImageIcon

import javax.swing.UIManager
import javax.swing.SwingUtilities

import java.awt.Desktop
import java.awt.BorderLayout
import java.awt.GridLayout
import java.awt.CardLayout
import java.awt.Color

class MainFrame < JFrame
  def initialize w, h
    super "Chamionat.com live notifyer"

    looks = UIManager::installed_look_and_feels
    UIManager::look_and_feel = looks[1].class_name
		SwingUtilities::update_component_tree_ui self

    $AGENT = Mechanize.new

    set_size w, h
    set_default_close_operation EXIT_ON_CLOSE

    $content_panel = JPanel.new CardLayout.new
    $live_panel = JPanel.new CardLayout.new

    controls_panel = JPanel.new

    $add_button = JButton.new "Следить"
    $remove_button = JButton.new "Не следить"
    $open_live_button = JButton.new "Открыть трансляцию"
    $open_match_button = JButton.new "Открыть матч"
    $check_box = JCheckBox.new "Показывать завершенные", true
    refresh_button = JButton.new "Обновить"

    controls_panel.add $check_box
    controls_panel.add $open_live_button
    controls_panel.add $open_match_button
    controls_panel.add refresh_button
    controls_panel.add $add_button
    controls_panel.add $remove_button

    $links = []


    $list_model = DefaultListModel.new
    $list = JList.new $list_model
    $list.set_selection_mode ListSelectionModel::SINGLE_SELECTION
    $list.set_selection_background Color::LIGHT_GRAY

    $live = JEditorPane.new
    $live.set_editable false

    loading_label = JLabel.new ImageIcon.new("#{Dir.pwd}/ajax-loader.gif")
    waiting_label = JLabel.new ImageIcon.new("#{Dir.pwd}/ajax-loader.gif")
    none_label = JLabel.new ImageIcon.new("#{Dir.pwd}/textspace.gif")

    list_scroll_pane = JScrollPane.new $list, JScrollPane::VERTICAL_SCROLLBAR_AS_NEEDED, JScrollPane::HORIZONTAL_SCROLLBAR_NEVER
    live_scroll_pane = JScrollPane.new $live, JScrollPane::VERTICAL_SCROLLBAR_AS_NEEDED, JScrollPane::HORIZONTAL_SCROLLBAR_NEVER

    $live_panel.add none_label, "none"
    $live_panel.add live_scroll_pane, "live"
    $live_panel.add loading_label, "load"

    main_panel = JPanel.new BorderLayout.new
    main_panel.add list_scroll_pane, BorderLayout::CENTER
    main_panel.add controls_panel, BorderLayout::SOUTH


    $content_panel.add main_panel, "main"
    $content_panel.add waiting_label, "wait"

    split_pane = JSplitPane.new JSplitPane::VERTICAL_SPLIT, $content_panel, $live_panel
    split_pane.set_divider_location get_height / 2

    $live.add_hyperlink_listener do |event|
      Desktop.get_desktop.browse java.net.URI.new(event.url.to_s) if event.get_event_type == Java::JavaxSwingEvent::HyperlinkEvent::EventType::ACTIVATED
    end

    $list.add_list_selection_listener do |event|
      break if event.get_value_is_adjusting
      if $links[$list.get_selected_index][:notify]
        $remove_button.set_enabled true
        $add_button.set_enabled false
      else
        $remove_button.set_enabled false
        $add_button.set_enabled !($links[$list.get_selected_index][:state].include? "конч")
      end
      $open_live_button.set_enabled true
      $open_match_button.set_enabled true

      update_live
    end

    update_matches

    $check_box.add_action_listener do
      update_matches
    end

    $add_button.add_action_listener do
      $links[$list.get_selected_index][:notify] = true
      update_matches
    end

    $remove_button.add_action_listener do
      $links[$list.get_selected_index][:notify] = false
      update_matches
    end

    refresh_button.add_action_listener do
      update_matches
    end

    $open_match_button.add_action_listener do
      Desktop.get_desktop.browse java.net.URI.new("http://championat.com#{$links[$list.get_selected_index][:url]}")
    end

    $open_live_button.add_action_listener do
      Desktop.get_desktop.browse java.net.URI.new(get_live_link_from_match_link($links[$list.get_selected_index][:url]))
    end

    add split_pane

    setVisible true

    Thread.new do
      repeat_every 10 do
        check
      end
    end
  end

  private

  def update_matches
    $content_panel.get_layout.show $content_panel, "wait"
    initialize_matches
    Thread.new do
      sleep 1
      $content_panel.get_layout.show $content_panel, "main"
    end
  end

  def get_color time, state
    now = Time.now
    hour, minutes = time.split ":"
    match_time = Time.local now.year, now.month, now.day, hour.to_i - 1, minutes
    if state.include? "конч"
      "red"
    else
       match_time > now ? "blue" : "green"
    end
  end

  def initialize_matches
    links_to_notify = $links.select { |link| link[:notify] }.map { |link| link[:url]}
    selected_match = $links[$list.get_selected_index][:url] if $list.get_selected_index >= 0
    $list_model.clear
    $links.clear

    page = $AGENT.get "http://championat.com/live.html"
    page.search("a[title='Текстовая трансляция']").each do |link|
      dd = link.parent.parent
      state = dd.search("dd[class='state']").text
      unless state.include? "конч" and not $check_box.is_selected
        url = link["href"]
        teams = dd.search("dt").text
        time = dd.search("dd[class='time']").text
        score = dd.search("span[class='score-set']").map { |span| span.text}.join(" ")
        score ||= dd.search("dd[class='score']").text
        $links << { :url => url, :state => state, :teams => teams, :size => 0, :notify => links_to_notify.include?(url) }
        color = get_color time, state
        $list_model.add $links.size - 1,
                        "<html>
                           <table>
                             <tr#{ " style='font-weight:bold;'" if $links.last[:notify] }>
                               <td width='40px' style='color: #{color};'>#{time}</td>
                               <td width='65px' style='border-left: 1px;'>#{score}</td>
                               <td width='75px' style='color: #{color};'>#{state}</td>
                               <td>#{teams}</td>
                             </tr>
                          </table>
                        </html>"
      end
    end

    $list.updateUI

    $add_button.set_enabled false
    $remove_button.set_enabled false
    $open_live_button.set_enabled false
    $open_match_button.set_enabled false

    $list.set_selected_index $links.index { |link| link[:url].eql? selected_match } if selected_match
  end

  def get_live_link_from_match_link url
    "http://championat.com#{ "#{url.split(".")[0..-2].join(".")}_live.htm"}"
  end

  def check
    $links.each_with_index do |match, index|
      if index == $list.get_selected_index or match[:notify]
        live = $AGENT.get get_live_link_from_match_link(match[:url])
        comments_count = live.search("tr").count
        if comments_count > match[:size]
          if match[:notify]
            tr = live.search("tr").first
            tds = tr.search "td"
            time = tds[0].text
            icon_url = tds[1].search("img").first["src"]
            icon_name = icon_url.split("/").last
            unless File.exists? "icons/#{icon_name}"
              f = File.open "icons/#{icon_name}", "w+"
              image = $AGENT.get icon_url
              f << image.body
              f.close
            end
            person = tds[2].text
            text = "#{tds[3].text}#{ "  #{tds[4].text}" if tds.size > 4}"
            if icon_name.eql? "empty.png"
              Libnotify.show :body => text, :summary => "#{time} #{person}", :time_out => 10
            else
              Libnotify.show(
                  :body => text,
                  :summary => "#{time} #{person} (#{match[:teams]})",
                  :icon_path => "#{Dir.pwd}/icons/#{icon_name}", :time_out => 10
              )
            end
          end

          match[:size] = comments_count

          update_live
        end
      end
    end
  end

  def update_live
    selected_index = $list.get_selected_index
    if selected_index >= 0
      live_link = get_live_link_from_match_link $links[selected_index][:url]
      $live_panel.get_layout.show $live_panel, "load"

      $live.set_page "http://ya.ru"
      $live.set_page live_link

      Thread.new do
        sleep live_link.eql?($prev_link) ? 0.1 : 1
        $live_panel.get_layout.show $live_panel, "live"
      end
      $prev_link = live_link
    else
      $live_panel.get_layout.show $live_panel, "none"
    end
  end

  def repeat_every(seconds)
    while true do
      sleep seconds
      yield
    end
  end
end
