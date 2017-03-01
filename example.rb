$LOAD_PATH.unshift("./lib")

require 'prometheus/client'
require 'prometheus/client/formats/text.rb'
require 'pp'

prometheus = Prometheus::Client.registry
Prometheus::Client::MmapedValue.set_pid(1)

counter1 = Prometheus::Client::Counter.new(:mycounter, 'Example counter')
counter2 = Prometheus::Client::Counter.new(:othercounter, 'Other counter')
gauge1 = Prometheus::Client::Gauge.new(:mygauge, 'Example gauge', {}, :livesum)
gauge2 = Prometheus::Client::Gauge.new(:othergauge, 'Other gauge', {}, :livesum)
histogram1 = Prometheus::Client::Histogram.new(:myhistogram, 'Example histogram', {}, [0, 1, 2])
histogram2 = Prometheus::Client::Histogram.new(:otherhistogram, 'Other histogram', {}, [0, 1, 2])
prometheus.register(counter1)
prometheus.register(counter2)
prometheus.register(gauge1)
prometheus.register(gauge2)
prometheus.register(histogram1)
prometheus.register(histogram2)

counter1.increment({'foo': 'bar'}, 2)
counter1.increment({'foo': 'biz'}, 4)
gauge1.set({'foo': 'bar'}, 3)
gauge1.set({'foo': 'biz'}, 1.0/0.0)
histogram1.observe({'foo': 'bar'}, 0.5)
histogram1.observe({'foo': 'bar'}, 3.5)
histogram1.observe({'foo': 'bar'}, 5.5)
histogram1.observe({'foo': 'bar'}, 2)

counter2.increment({'foo': 'bar'}, 2)
counter2.increment({'foo': 'biz'}, 4)
gauge2.set({'foo': 'bar'}, 3)
gauge2.set({'foo': 'biz'}, 3)
histogram2.observe({'foo': 'bar'}, 0.5)
histogram2.observe({'foo': 'bar'}, 1.5)
histogram2.observe({'foo': 'biz'}, 0.5)
histogram2.observe({'foo': 'biz'}, 2)

#puts Prometheus::Client::Formats::Text.marshal(prometheus)

puts Prometheus::Client::Formats::Text.marshal_multiprocess
