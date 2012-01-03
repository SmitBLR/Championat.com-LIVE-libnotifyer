import javax.swing.ListSelectionModel
import javax.swing.JFrame
import javax.swing.JPanel
import javax.swing.JButton
import javax.swing.JTextField
import javax.swing.JList
import javax.swing.JScrollPane
import javax.swing.JCheckBox
import javax.swing.DefaultListModel
import java.awt.Desktop

import java.awt.BorderLayout

class MainFrame < JFrame
  def initialize w, h
    super "Chamionat.com live notifyer"

    $AGENT = Mechanize.new

    setSize w, h
    setDefaultCloseOperation EXIT_ON_CLOSE

    setLayout BorderLayout.new
    controls_panel = JPanel.new

    $add_button = JButton.new "Следить"
    $remove_button = JButton.new "Не следить"
    $open_live_button = JButton.new "Открыть трансляцию"
    $open_match_button = JButton.new "Открыть матч"
    refresh_button = JButton.new "Обновить"

    $links = []
    $links_to_parse = []
    $list_model = DefaultListModel.new
    $list = JList.new $list_model
    $check_box = JCheckBox.new "Показывать завершенные", true
    $list.setSelectionMode ListSelectionModel::SINGLE_SELECTION

    scroll_pane = JScrollPane.new $list

    $list.addListSelectionListener do
      if $links_to_parse.map { |l| l[:url] }.include? $links[$list.getSelectedIndex][:url]
        $remove_button.setEnabled true
        $add_button.setEnabled false
      else
        $remove_button.setEnabled false
        $add_button.setEnabled !($links[$list.getSelectedIndex][:state].include? "конч")
      end
      $open_live_button.setEnabled true
      $open_match_button.setEnabled true
    end

    initialize_matches

    $check_box.addActionListener do
      initialize_matches
    end

    $add_button.addActionListener do
      $links_to_parse << { :url => $links[$list.getSelectedIndex][:url], :size => 0 }
      initialize_matches
    end

    $remove_button.addActionListener do
      $links_to_parse.delete_if { |l| l[:url].eql? $links[$list.getSelectedIndex][:url] }
      initialize_matches
    end

    refresh_button.addActionListener do
      initialize_matches
    end

    $open_match_button.addActionListener do
      Desktop.getDesktop.browse java.net.URI.new("http://championat.com#{$links[$list.getSelectedIndex][:url]}")
    end

    $open_live_button.addActionListener do
      Desktop.getDesktop.browse java.net.URI.new("http://championat.com#{ "#{$links[$list.getSelectedIndex][:url].split(".")[0..-2].join(".")}_live.htm"}")
    end

    controls_panel.add $check_box
    controls_panel.add $open_live_button
    controls_panel.add $open_match_button
    controls_panel.add refresh_button
    controls_panel.add $add_button
    controls_panel.add $remove_button

    add controls_panel, BorderLayout::SOUTH
    add scroll_pane, BorderLayout::CENTER
    setVisible true

    Thread.new do
      repeat_every 10 do
        check
      end
    end

    Thread.new do
      repeat_every 120 do
        initialize_matches
      end
    end
  end

  private

  def initialize_matches
    $list_model.clear
    $links.clear

    page = $AGENT.get "http://championat.com/live.html"
    page.search("a[title='Текстовая трансляция']").each do |link|
      dd = link.parent.parent
      state = dd.search("dd[class='state']").text
      unless state.eql? "окончен" and not $check_box.isSelected
        url = link["href"]
        $links << { :url => url, :state => state }
        teams = dd.search("dt").text
        time = dd.search("dd[class='time']").text
        score = dd.search("dd[class='score']").text
        $list_model.add $links.size - 1,
                        "<html>
                           <table>
                             <tr#{ " style='color: green;'" if $links_to_parse.map { |l| l[:url] }.include? url }>
                               <td width='40px'>#{time}</td>
                               <td width='65px'>#{score}</td>
                               <td width='75px'>#{state}</td>
                               <td>#{teams}</td>
                             </tr>
                          </table>
                        </html>"
      end
    end
    $links_to_parse.delete_if { |link| not $links.map { |l| l[:state].include?("конч") ? "" : l[:url] }.include? link[:url] }

    $list.updateUI

    $add_button.setEnabled false
    $remove_button.setEnabled false
    $open_live_button.setEnabled false
    $open_match_button.setEnabled false
  end

  def check
    #puts "#{Time.now} check"
    $links_to_parse.each do |match|
      live = $AGENT.get "http://championat.com#{ "#{match[:url].split(".")[0..-2].join(".")}_live.htm"}"
      comments_count = live.search("tr").count
      if comments_count > match[:size]
        tr = live.search("tr").first
        tds = tr.search "td"
        time = tds[0].text
        icon_url = tds[1].search("img").first["src"]
        icon_name = icon_url.split("/").last
        unless File.exists? icon_name
          f = File.open icon_name, "w+"
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
              :summary => "#{time} #{person}",
              :icon_path => "#{Dir.pwd}/#{icon_name}", :time_out => 10
          )
        end

        match[:size] = comments_count
      end
    end
  end

  def repeat_every(seconds)
    while true do
      sleep seconds
      yield
    end
  end
end
