require 'sinatra'
require 'rest-client'
require 'json'

module Uniboard
  class APIClient
    LIRR_STOPS = {
      "NYK"=>"Penn Station", "ABT"=>"Albertson", "AGT"=>"Amagansett",
      "AVL"=>"Amityville", "ATL"=>"Atlantic Terminal", "ADL"=>"Auburndale",
      "BTA"=>"Babylon", "BWN"=>"Baldwin", "BSR"=>"Bay Shore", "BSD"=>"Bayside",
      "BRS"=>"Bellerose", "BMR"=>"Bellmore", "BPT"=>"Bellport", "BRT"=>"Belmont",
      "BPG"=>"Bethpage", "BWD"=>"Brentwood", "BHN"=>"Bridgehampton", "BDY"=>"Broadway",
      "CPL"=>"Carle Place", "CHT"=>"Cedarhurst", "CI"=>"Central Islip",
      "CAV"=>"Centre Avenue", "CSH"=>"Cold Spring Harbor", "CPG"=>"Copiague",
      "CLP"=>"Country Life Press", "DPK"=>"Deer Park", "DGL"=>"Douglaston",
      "EHN"=>"East Hampton", "ENY"=>"East New York", "ERY"=>"East Rockaway",
      "EWN"=>"East Williston", "FRY"=>"Far Rockaway", "FMD"=>"Farmingdale",
      "FPK"=>"Floral Park", "FLS"=>"Flushing Main Street", "FHL"=>"Forest Hills",
      "FPT"=>"Freeport", "GCY"=>"Garden City", "GBN"=>"Gibson", "GCV"=>"Glen Cove",
      "GHD"=>"Glen Head", "GST"=>"Glen Street", "GNK"=>"Great Neck", "GRV"=>"Great River",
      "GWN"=>"Greenlawn", "GPT"=>"Greenport", "GVL"=>"Greenvale", "HBY"=>"Hampton Bays",
      "HGN"=>"Hempstead Gardens", "HEM"=>"Hempstead", "HWT"=>"Hewlett", "HVL"=>"Hicksville",
      "HOL"=>"Hollis", "HPA"=>"Hunterspoint Avenue", "HUN"=>"Huntington", "IWD"=>"Inwood",
      "IPK"=>"Island Park", "ISP"=>"Islip", "JAM"=>"Jamaica", "KGN"=>"Kew Gardens",
      "KPK"=>"Kings Park", "LVW"=>"Lakeview", "LTN"=>"Laurelton", "LCE"=>"Lawrence",
      "LHT"=>"Lindenhurst", "LNK"=>"Little Neck", "LMR"=>"Locust Manor",
      "LVL"=>"Locust Valley", "LBH"=>"Long Beach", "LIC"=>"Long Island City",
      "LYN"=>"Lynbrook", "MVN"=>"Malverne", "MHT"=>"Manhasset", "MPK"=>"Massapequa Park",
      "MQA"=>"Massapequa", "MSY"=>"Mastic Shirley", "MAK"=>"Mattituck", "MFD"=>"Medford",
      "MAV"=>"Merillon Avenue", "MRK"=>"Merrick", "SSM"=>"Mets-Willets Point",
      "MIN"=>"Mineola", "MTK"=>"Montauk", "MHL"=>"Murray Hill", "NBD"=>"Nassau Boulevard",
      "NHP"=>"New Hyde Park", "NPT"=>"Northport", "NAV"=>"Nostrand Avenue", "ODL"=>"Oakdale",
      "ODE"=>"Oceanside", "OBY"=>"Oyster Bay", "PGE"=>"Patchogue", "PLN"=>"Pinelawn",
      "PDM"=>"Plandome", "PJN"=>"Port Jefferson", "PWS"=>"Port Washington",
      "QVG"=>"Queens Village", "RHD"=>"Riverhead", "RVC"=>"Rockville Centre",
      "RON"=>"Ronkonkoma", "ROS"=>"Rosedale", "RSN"=>"Roslyn", "SVL"=>"Sayville",
      "SCF"=>"Sea Cliff", "SFD"=>"Seaford", "STN"=>"Smithtown", "SHN"=>"Southampton",
      "SHD"=>"Southold", "SPK"=>"Speonk", "SAB"=>"St. Albans", "SJM"=>"St. James",
      "SMR"=>"Stewart Manor", "BK"=>"Stony Brook", "SYT"=>"Syosset", "VSM"=>"Valley Stream",
      "WGH"=>"Wantagh", "WHD"=>"West Hempstead", "WBY"=>"Westbury", "WHN"=>"Westhampton",
      "WWD"=>"Westwood", "WMR"=>"Woodmere", "WDD"=>"Woodside", "WYD"=>"Wyandanch",
      "YPK"=>"Yaphank"
    }.freeze

    def self.get_lirr
      trains = RestClient.get('https://traintime.lirr.org/api/Departure?loc=NYK')
      trains = JSON.parse(trains)['TRAINS']
      trains.each do |t|
        # Process carrier
        t['CARRIER'] = 'LIRR'

        # Process time
        t['TIME'] = DateTime.strptime(t['SCHED'], '%m/%d/%Y %H:%M:%S')

        # Process status
        time = Time.strptime(t['ETA'], '%m/%d/%Y %H:%M:%S')- Time.now
        t['STATUS'] = "in #{(time/60).to_i} min(s)"

        # Process destination
        flags = []

        if t['JAM']
          flags << '<b>J</b>'
        end

        if flags.size > 0
          flags = ' (' + flags.join(', ') + ')'
        else
          flags = ''
        end

        t['DESTINATION'] = LIRR_STOPS[t['DEST']] + flags
      end
    end

    def self.get_njt_amtk
      trains = RestClient.get('http://199.184.144.61/NJTAppWS2/services/getDV?station=NY', { 'Host' => 'app.njtransit.com' })
      #File.open(Dir.pwd + '/njt.json', 'w') { |f| f.puts trains }
      #trains = File.read(Dir.pwd + '/njt.json')
      trains = JSON.parse(trains[9..(trains.length - 2)])
      trains = trains['STATION']['ITEMS']['ITEM']
      trains.each do |t|
        # Process carrier
        if t['TRAIN_ID'].include?('A')
          t['CARRIER'] = 'AMTRAK'
        else
          t['CARRIER'] = 'NJT'
        end

        # Process time
        t['TIME'] = DateTime.strptime(t['SCHED_DEP_DATE'], '%d-%b-%Y %H:%M:%S %p')

        # Process destination
        flags = []
        if t['DESTINATION'].include?('-')
          dest = t['DESTINATION'].split('-')

          if dest.find { |d| d.include?('SEC') }
            flags << '<b>SEC</b>'
          end
        else
          dest = [t['DESTINATION']]
        end

        if dest.find { |d| d.include?('&#9992') }
          flags << '<b>EWR</b>'
        end

        if flags.size > 0
          flags = ' (' + flags.join(', ') + ')'
        else
          flags = ''
        end

        t['DESTINATION'] = dest[0].sub(' &#9992', '') + flags
      end
    end
  end

  class Application < Sinatra::Application
    get '/' do
      trains = []
      trains.concat APIClient.get_lirr
      trains.concat APIClient.get_njt_amtk

      trains.sort! { |a, b| a['TIME'] <=> b['TIME'] }

      erb :index, locals: { trains: trains }
    end
  end
end
