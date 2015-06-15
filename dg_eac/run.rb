require 'csv'
require 'json'

# From http://open-data.europa.eu/data/dataset/erasmus-mobility-statistics-2012-13
# Raw data of Erasmus student mobility (study exchanges and work placements in 2012-13) 
#studmobcsv = 'input/SM_2012_13_20141103_01.partial.csv' # partial input for quick testing
studmobcsv = 'input/SM_2012_13_20141103_01.csv'

allCountries = Hash.new
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
  age = row[4]
  allCountries[homeC] = 1
  allCountries[hostC] = 1
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


homeCountryToGenderHash = Hash.new
hostCountryToGenderHash = Hash.new
allCountries.keys.sort.each{ |c|
  genderHash = Hash.new
  genderHash['Male'] = homeCountryToNumberOfMaleParticipants.fetch(c,0)
  genderHash['Female'] = homeCountryToNumberOfFemaleParticipants.fetch(c,0)
  homeCountryToGenderHash[c] = genderHash

  genderHash = Hash.new
  genderHash['Male'] = hostCountryToNumberOfMaleParticipants.fetch(c,0)
  genderHash['Female'] = hostCountryToNumberOfFemaleParticipants.fetch(c,0)
  hostCountryToGenderHash[c] = genderHash  
}

def writeHtmlForGraph(templateFileName, name, keyname, valname, description, indexPage)
  s = IO.read(templateFileName)
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

def createOneToOneGraph(name, hash, keyname, valname, description, indexPage)
  tsvfilename = 'out/' + name + '.tsv'
  f = File.open(tsvfilename,'w')
  f << keyname + "\t" + valname + "\n" + hash.keys.sort.map {|c| c + "\t" + hash[c].to_s }.join("\n")
  f.close
  jsonfilename = 'out/' + name + '.json'
  f = File.open(jsonfilename,'w')
  f << hash.to_json
  f.close
  templateFileName = 'html/oneToOneTemplate-only-pos-values.html'
  if hash.values.min < 0 then
    templateFileName = 'html/oneToOneTemplate-with-neg-values.html'
  end
  writeHtmlForGraph(templateFileName, name, keyname, valname, description, indexPage)
end

def createGroupedBarsGraph(name, hash, keyname, valname, description, indexPage)
  tsvfilename = 'out/' + name + '.tsv'
  f = File.open(tsvfilename, 'w')
  keyNames = hash.values[0].keys
  f << keyname + "\t" + keyNames.join("\t") + "\n"
  f << hash.keys.sort.map { |c| c + "\t" + keyNames.map { |k| hash[c][k].to_s }.join("\t") }.join("\n")
  f.close
  # TODO write json file
  templateFileName = 'html/groupedBarTemplate-only-pos-values.html'
  writeHtmlForGraph(templateFileName, name, keyname, valname, description, indexPage)
end



def createBoxPlotGraph(name, hash, keyname, valname, description, indexPage)
  tsvfilename = 'out/' + name + '.tsv'
  f = File.open(tsvfilename, 'w')
  f << keyname + "\tmin\tlowerq\tmedian\tupperq\tmax\n"
  f << hash.keys.sort.map { |c|
    a = hash[c].sort
    medIndex = (a.length/2).floor
    lowerqIndex = (medIndex/2).floor
    upperqIndex = ((a.length-medIndex)/2).floor+medIndex
    print "l:" + a.length.to_s + ",med:" + medIndex.to_s + ",lowerq:" + lowerqIndex.to_s + ",upperq:" + upperqIndex.to_s + "\n"
    c + "\t" + a.min.to_s + "\t" + a[lowerqIndex].to_s + "\t" + a[medIndex].to_s + "\t" + a[upperqIndex].to_s + "\t" + a.max }.join("\n")
  f.close
  #templateFileName = 'html/boxPlotTemplate.html'
  #writeHtmlForGraph(templateFileName, name, keyname, valname, description, indexPage)
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
createGroupedBarsGraph('homeCountryToGenderHash',homeCountryToGenderHash,'country','participants','Number of male and female particpants per home country', indexPage)
createGroupedBarsGraph('hostCountryToGenderHash',hostCountryToGenderHash,'country','participants','Number of male and female particpants per host country', indexPage)
createBoxPlotGraph('homeCountryToArrayOfStudentAge', homeCountryToArrayOfStudentAge, 'country', 'participants', 'Age of participants per home country', indexPage)
createBoxPlotGraph('hostCountryToArrayOfStudentAge', hostCountryToArrayOfStudentAge, 'country', 'participants', 'Age of participants per host country', indexPage)


s = IO.read('html/indexPageTemplate.html')
s = s.gsub('__CONTENTS__', indexPage.string)
f = File.open('out/index.html','w')
f << s
f.close
