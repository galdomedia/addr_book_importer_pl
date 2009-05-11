Użycie jest banalne:

@
require 'contact_importer'
include ContactImporter
o = Gmail.new('login', 'password')
o.get_addresses # lista rekordów [login, email]
@

