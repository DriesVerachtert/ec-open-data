require 'csv'
require 'json'

# From http://open-data.europa.eu/data/dataset/erasmus-mobility-statistics-2012-13
# Raw data of Erasmus student mobility (study exchanges and work placements in 2012-13) 
#studmobcsv = 'input/SM_2012_13_20141103_01.partial.csv' # partial input for quick testing
studmobcsv = 'input/SM_2012_13_20141103_01.csv'

homeCountryToNumberOfParticipants = Hash.new
hostCountryToNumberOfParticipants = Hash.new
countryToHomeToHostRatio = Hash.new
homeCountryToNumberOfMaleParticipants = Hash.new
homeCountryToNumberOfFemaleParticipants = Hash.new
hostCountryToNumberOfMaleParticipants = Hash.new
hostCountryToNumberOfFemaleParticipants = Hash.new
homeCountryToArrayOfStudentAge = Hash.new
hostCountryToArrayOfStudentAge = Hash.new


CSV.foreach(studmobcsv, :headers => true , :encoding => 'ISO-8859-1', :quote_char => '"', :col_sep => ';') do |row|
  # hostC = host country
  hostC = row[12] # for normal students
  if hostC == '???' then # staff (i think) doesn't have a host institution and country
    hostC = row[14] # take the country of the enterprise
    if hostC == nil then # 3 lines with bad data
      hostC = '??'
    end
  end
  hostC = hostC[0..1] # BEDE => BE
  # homeC = home country
  homeC = row[3]
  homeC = homeC[0..1] # BEDE => BE
  gender = row[5]
  age = row[6]
  homeCountryToArrayOfStudentAge[homeC] = homeCountryToArrayOfStudentAge.fetch(homeC,Array.new).push(age)
  hostCountryToArrayOfStudentAge[hostC] = hostCountryToArrayOfStudentAge.fetch(hostC,Array.new).push(age)
  
  homeCountryToNumberOfParticipants[homeC] = homeCountryToNumberOfParticipants.fetch(homeC,0) + 1
  hostCountryToNumberOfParticipants[hostC] = hostCountryToNumberOfParticipants.fetch(hostC,0) + 1
  countryToHomeToHostRatio[homeC] = countryToHomeToHostRatio.fetch(homeC,0) + 1
  countryToHomeToHostRatio[hostC] = countryToHomeToHostRatio.fetch(hostC,0) - 1
  if gender == 'M' then
    homeCountryToNumberOfMaleParticipants[homeC] = homeCountryToNumberOfMaleParticipants.fetch(homeC,0) + 1
    hostCountryToNumberOfMaleParticipants[hostC] = hostCountryToNumberOfMaleParticipants.fetch(hostC,0) + 1
  end
  if gender == 'F' then
    homeCountryToNumberOfFemaleParticipants[homeC] = homeCountryToNumberOfFemaleParticipants.fetch(homeC,0) + 1
    hostCountryToNumberOfFemaleParticipants[hostC] = hostCountryToNumberOfFemaleParticipants.fetch(hostC,0) + 1
  end
end

homeCountryToPercentageOfMaleParticipants = Hash.new
homeCountryToPercentageOfFemaleParticipants = Hash.new
hostCountryToPercentageOfMaleParticipants = Hash.new
hostCountryToPercentageOfFemaleParticipants = Hash.new
homeCountryToNumberOfParticipants.keys.map {|c|
  homeCountryToPercentageOfMaleParticipants[c] = homeCountryToNumberOfMaleParticipants.fetch(c,0) * 100 / homeCountryToNumberOfParticipants[c]
  homeCountryToPercentageOfFemaleParticipants[c] = homeCountryToNumberOfFemaleParticipants.fetch(c,0) * 100 / homeCountryToNumberOfParticipants[c]
}
hostCountryToNumberOfParticipants.keys.map {|c|
  hostCountryToPercentageOfMaleParticipants[c] = hostCountryToNumberOfMaleParticipants.fetch(c,0) * 100 / hostCountryToNumberOfParticipants[c]
  hostCountryToPercentageOfFemaleParticipants[c] = hostCountryToNumberOfFemaleParticipants.fetch(c,0) * 100 / hostCountryToNumberOfParticipants[c]
}

def createOneToOneGraph(name, hash, keyname, valname, description, indexPage)
  tsvfilename = 'out/' + name + '.tsv'
  f = File.open(tsvfilename,'w')
  f << keyname + "\t" + valname + "\n" + hash.keys.sort.map {|c| c + "\t" + hash[c].to_s }.join("\n")
  f.close
  jsonfilename = 'out/' + name + '.json'
  f = File.open(jsonfilename,'w')
  f << hash.to_json
  f.close
  s = IO.read('html/oneToOneTemplate2.html')
  s = s.gsub('__YAXIS__',valname).gsub('__XAXIS__',keyname).gsub('__DESCRIPTION__',description).gsub('__TSVFILENAME__',name + '.tsv')
  f = File.open('out/' + name + '.html','w')
  f << s
  f.close
  indexPage << '<h2>' + description + '</h2>'
  indexPage << '<h3>Raw data</h3>'
  indexPage << '<ul><li><a href="' + name + '.tsv">' + name + '.tsv</a></li>'
  indexPage << '<li><a href="' + name + '.json">' + name + '.json</a></li></ul>'
  indexPage << '<h3>Graph</h3>'
  indexPage << '<iframe width="1150" height="650" src="' + name + '.html"></iframe>'
end

indexPage = StringIO.new
indexPage << '<h1>Erasmus student mobility (study exchanges and work placements in 2012-13)</h1>'
indexPage << 'Based on <a href="http://open-data.europa.eu/data/dataset/erasmus-mobility-statistics-2012-13">the raw data of Erasmus student mobility (study exchanges and work placements in 2012-13)</a>'

createOneToOneGraph('homeCountryToNumberOfParticipants', homeCountryToNumberOfParticipants, 'country', 'participants', 'Number of participants per home country', indexPage)
createOneToOneGraph('hostCountryToNumberOfParticipants', hostCountryToNumberOfParticipants, 'country', 'participants', 'Number of participants per host country', indexPage)
createOneToOneGraph('countryToHomeToHostRatio', countryToHomeToHostRatio, 'country', 'ratio', 'Number of outgoing minus the number of incoming participants per country', indexPage)
createOneToOneGraph('homeCountryToNumberOfMaleParticipants', homeCountryToNumberOfMaleParticipants, 'country', 'participants', 'Number of male participants per home country', indexPage)
createOneToOneGraph('homeCountryToNumberOfFemaleParticipants', homeCountryToNumberOfFemaleParticipants, 'country', 'participants', 'Number of female participants per home country', indexPage)
createOneToOneGraph('hostCountryToNumberOfMaleParticipants', hostCountryToNumberOfMaleParticipants, 'country', 'participants', 'Number of male participants per host country', indexPage)
createOneToOneGraph('hostCountryToNumberOfFemaleParticipants', hostCountryToNumberOfFemaleParticipants, 'country', 'participants', 'Number of female participants per host country', indexPage)
createOneToOneGraph('homeCountryToPercentageOfMaleParticipants', homeCountryToPercentageOfMaleParticipants, 'country', 'percentage', 'Percentage of male participants per home country', indexPage)
createOneToOneGraph('homeCountryToPercentageOfFemaleParticipants', homeCountryToPercentageOfFemaleParticipants, 'country', 'percentage', 'Percentage of female participants per home country', indexPage)
createOneToOneGraph('hostCountryToPercentageOfMaleParticipants', hostCountryToPercentageOfMaleParticipants, 'country', 'percentage', 'Percentage of male participants per host country', indexPage)
createOneToOneGraph('hostCountryToPercentageOfFemaleParticipants', hostCountryToPercentageOfFemaleParticipants, 'country', 'percentage', 'Percentage of female participants per host country', indexPage)

s = IO.read('html/indexPageTemplate.html')
s = s.gsub('__CONTENTS__', indexPage.string)
f = File.open('out/index.html','w')
f << s
f.close
