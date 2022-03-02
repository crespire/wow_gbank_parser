require 'csv'

csv = CSV.open('audit.txt')

csv.sort.each do |row|
  p row
end