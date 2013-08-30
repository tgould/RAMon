class Ramon < Adhearsion::CallController
	def run

	    ## Define
	    file_links  = []
	    web_uri     = 'https://gears002.scl.five9.com:15000'
	    five9domains = {
		"StraightForward"=>{"domainId"=>"/103856", "auth_pw"=>"6714"},
		"AWWC2"=>{"domainId"=>"/108106", "auth_pw"=>"2992"},
		"AWWC3"=>{"domainId"=>"/108461", "auth_pw"=>"2881"},
		"AWWC4"=>{"domainId"=>"/108737", "auth_pw"=>"2887"},
		"AWWC5"=>{"domainId"=>"/109594", "auth_pw"=>"8921"},
		"AWWC6"=>{"domainId"=>"/110496", "auth_pw"=>"8662"},
		"AWWC7"=>{"domainId"=>"/112365", "auth_pw"=>"8663"}
		}
		keys 			= five9domains.keys
		rec_path		= ''
		rec_storage 	= '/var/lib/asterisk/sounds/ramon/'
	    user        	= "test"
	    password    	= "123"
	    auth     		= ""
	    pw          	= ""
	    min_rec_size 	= 50000

	    answer
	    ### Authentication
	    while auth != "true" do
			sleep 1
			pw = ask 'enter-4-digit-password', limit: 4, renderer: :asterisk
			for key in 0...keys.length
				if pw.to_s == five9domains[keys[key]]["auth_pw"]
					rec_path = five9domains[keys[key]]["domainId"]
					auth = "true"
					page_uri = web_uri + rec_path
				end
			end
			if auth != "true"
				play 'login-incorrect', renderer: :asterisk
			end
		end

	    #######################################################################
	    ### Retrieve latest recording list
	    basic_str        = "Basic #{Base64.encode64(user+":"+password)}"
		url              = URI.parse(page_uri)
	    http             = Net::HTTP.new(url.host,url.port)
	    http.use_ssl     = true
	    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
	    resp             = http.get(url.path, {"Authorization"=>basic_str})

	    #######################################################################
	    ### Process links into array
	    logger.info "Process links into array"
	    html_doc = Nokogiri::HTML(resp.body)
	    html_doc.css('a').each_with_index do |a_link, index|
			file_links << a_link['href']
	    end

	    catch :done do	    	
			### Process each recording link, download, re-encode and play.
			file_links.each_with_index do |file_link, index|
			    file_url = URI.escape(web_uri + file_link)
			    resp = http.get(file_url, {"Authorization" => basic_str})
			    in_file_name = rec_storage + index.to_s + 'in.wav'
			    out_file_name = rec_storage + index.to_s + 'out.wav'
			    
			    File.open(in_file_name, 'w') { |f| f.write(resp.body) }
		    	fileSize = File.size(in_file_name)
			    
			    if fileSize > min_rec_size then
					convert = "sox " + in_file_name + " -s " + out_file_name
					system(convert)
					File.delete(in_file_name)
				    play 'beep', renderer: :asterisk
					
					dtmf = nil
					begin
						dtmf = interruptible_play (rec_storage + index.to_s + "out"), renderer: :asterisk
						if dtmf == '0'
							throw :done
						elsif dtmf != '1'
							break
						end		
					end while dtmf == '1'
					
					if dtmf.nil?
						sleep 3
					end
			    
			    else logger.info "File size '#{fileSize} too small.  File Skipped"
			    end
			end
		
			play 'vm-nomore', renderer: :asterisk
	    end
	    
	    play 'goodbye', renderer: :asterisk
    end

end