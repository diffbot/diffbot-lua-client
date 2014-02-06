local diffbot, d, c

diffbot = require 'diffbot'

d = diffbot 'DEVELOPER_TOKEN'

c = d:analyze 'http://diffbot.com/products/'

diffbot.debug.print_r(c)
