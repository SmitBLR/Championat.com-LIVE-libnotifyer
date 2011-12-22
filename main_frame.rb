import javax.swing.JFrame
import javax.swing.JPanel
import javax.swing.JButton
import javax.swing.JTextField
import javax.swing.JList
import javax.swing.DefaultListModel

import java.awt.BorderLayout

class MainFrame < JFrame
  def initialize w, h
    super "Chamionat.com live notifyer"
    setSize w, h
    setDefaultCloseOperation EXIT_ON_CLOSE

    setLayout BorderLayout.new
    controls_panel = JPanel.new

    @list_model = DefaultListModel.new
    @list = JList.new @list_model

    url_field = JTextField.new 40
    ok_button = JButton.new "Ok"

    ok_button.addActionListener do
      @list_model.clear
      @not_first_parse = nil
      @url = "#{url_field.getText.split(".")[0..-2].join(".")}_live.htm"
      repeat_every 20 do
        check
      end
    end

    controls_panel.add url_field
    controls_panel.add ok_button

    add @list, BorderLayout::CENTER
    add controls_panel, BorderLayout::SOUTH

    setVisible true
  end

  private

  def get_comment time, icon_url, person, text
    "#{time} | #{person} | #{text}"
  end

  def check
    puts "#{Time.now} check"
    agent = Mechanize.new

    live = agent.get @url

    first_comment = @list_model.getSize ? "" : @list_model.get(0)

    live.search("tr").each do |tr|
      tds = tr.search "td"
      time = tds[0].text
      icon = tds[1].search "img"
      icon_url = nil
      unless icon.size
        icon_url = icon.search("img").first.attributes["src"].value
      end
      person = tds[2].text
      text = "#{tds[3].text}#{ " | #{tds[4].text}" if tds.size > 4}"

      comment = get_comment time, icon_url, person, text

      break if first_comment == comment

      @list_model.insertElementAt comment, 0

      Libnotify.show(:body => comment, :summary => "#{time} #{person}") if @not_first_parse
    end
    @not_first_parse = true

    @list.updateUI
  end

  def time_block
    start_time = Time.now
    yield
    Time.now - start_time
  end

  def repeat_every(seconds)
    while true do
      sleep( seconds - time_block { yield } )
    end
  end
end