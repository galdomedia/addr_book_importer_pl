require 'rubygems'
require 'nokogiri'
require 'mechanize'
require 'fastercsv'

module ContactImporter
  class Importer
    private
    attr_accessor :login, :password
    public

    def initialize(login, password)
      self.login = login
      self.password = password
    end

    def csv_to_array(content)
      arr_of_arrs = FasterCSV.parse(content)
      arr_of_arrs
    end

    def get_addresses
    end

  end
  class WP < Importer
    def get_addresses
      agent = WWW::Mechanize.new
      agent.user_agent_alias = 'Mac Safari'
      page = agent.get('http://profil.wp.pl/login.html')
      form = page.forms[0]
      form.fields.find{|f| f.name == 'login_username'}.value = login
      form.fields.find{|f| f.name == 'login_password'}.value = password
      page = agent.submit(form)
      page = agent.get('http://ksiazka-adresowa.wp.pl/import-export.html')
      form = page.forms[1]
      form.fields.find{|f| f.name == 'gr_id'}.value = '0'
      form.fields.find{|f| f.name == 'program'}.value = 'gm'
      page = agent.submit(form)
      vals = csv_to_array(page.body)[1..-1]
      ret = []
      vals.each{|r| ret << [r[0], r[1]] }
      ret
    end
  end

  class Interia < Importer
    def get_addresses
      # login: test@domain
      l = login
      login, domain = l.split('@')
      domain = "interia.pl" if domain.blank?
      agent = WWW::Mechanize.new
      agent.user_agent_alias = 'Mac Safari'
      page = agent.get('http://poczta.interia.pl/')
      form = page.forms[0]
      form.fields.find{|f| f.name == 'login'}.value = login
      form.fields.find{|f| f.name == 'pass'}.value = password
      form.fields.find{|f| f.name == 'domain'}.value = domain
      page = agent.submit(form)
      page = agent.get("http://poczta.interia.pl/classic/")
      page = page.links.find{|l| l.text =~ /\.*kontakty\.*/}.click()
      page = page.links.find{|l| l.text =~ /\.*eksportuj/}.click()
      page = agent.post(page.forms[0].action,  [["contactslistExport", "gmail"], ["contactslistExportSubmit", "Eksportuj"]])
      vals = csv_to_array(page.body)[1..-1]
      ret = []
      vals.each{|r| ret << [r[0], r[1]] }
      ret
    end
  end

  class O2 <Importer
    def get_addresses
      agent = WWW::Mechanize.new
      agent.user_agent = 'Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.0)'
      page = agent.get('http://poczta.o2.pl/')
      form = page.forms[0]
      form.fields.find{|f| f.name == 'username'}.value = login
      form.fields.find{|f| f.name == 'password'}.value = password
      form.fields << WWW::Mechanize::Form::Field.new("forcens", "true")
      page = agent.submit(form)
      page = agent.get('http://poczta.o2.pl/addressbook/')
      form = page.forms.find{|f| f.action == "/addressbook/export/"}
      form.fields.find{|f| f.name == 'export_mode'}.value = 'Gecko'
      page = agent.submit(form)
      vals = []
      page.body.split("\n").each do |row|
        v = row.split(',')
        vals << [v[3], v[4]]
      end
      vals
    end
  end

  class GoogleApps < Importer
    def return_addresses_from_body(body)
      contacts = []
      doc = Nokogiri::HTML(body)
      doc.xpath('//table[@class="th"]/tr').each do |tr|
          if tr.to_s =~ /checkbox/
            c = []
            tr.xpath('td').each do |td|
              unless td.to_s =~ /checkbox/
                t = td.to_s.gsub(/<\/?[^>]*>/, "").strip
                if c. length == 1
                  email = t.match(/([^@\s*]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})/i)
                  if email
                    c << email[0]
                  end
                else
                  c << t
                end
              end
            end
            contacts << c if c.length==2
          end
      end
     contacts
    end
  end

  class Gmail < GoogleApps
    def get_addresses
      agent = WWW::Mechanize.new
      agent.user_agent_alias = 'Mac Safari'
      page = agent.get('http://mail.google.com/mail/')
      form = page.forms[0]
      form.fields.find{|f| f.name == 'Email'}.value = login
      form.fields.find{|f| f.name == 'Passwd'}.value = password
      page = agent.submit(form)
      page = agent.get('http://mail.google.com/mail/?ui=html&zy=a')
      page = agent.get('http://mail.google.com/mail/?v=cl&ui=html')
      page = page.links.find{|l| l.href =~ /pnl=a/}.click()
      return_addresses_from_body(page.body)
    end
  end

  class Gazeta < GoogleApps
    def get_addresses
      agent = WWW::Mechanize.new
      agent.user_agent_alias = 'Mac Safari'
      page = agent.get('http://mail.google.com/a/gazeta.pl/?zy=e&f=1')
      form = page.forms[0]
      form.fields.find{|f| f.name == 'username'}.value = login
      form.fields.find{|f| f.name == 'password'}.value = password
      page = agent.submit(form)
      form = page.forms[0]
      page = agent.submit(form)
      page = agent.get('http://mail.google.com/a/gazeta.pl/?ui=html&zy=a')
      page = agent.get('http://mail.google.com/a/gazeta.pl/?v=cl&ui=html')
      page = page.links.find{|l| l.href =~ /pnl=a/}.click()
      return_addresses_from_body(page.body)
    end
  end 
end
