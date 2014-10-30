Facter.add('site') do
  setcode do
    Facter.value(:domain).split('.').first
  end
end
