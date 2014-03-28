module Puppet::Parser::Functions
  newfunction(:get_array_id, :type => :rvalue) do |args|
    array = args[0]
    obj = args[1]
    h = {}
    array.each_with_index do |v,i|
      h[v] = i
    end
    h[obj] + 1
  end
end
