class YoutubeEdlController  < ActionController::Base

require 'erb'
$template = ERB.new File.read(RAILS_ROOT + "/app/views/youtube_edl/control_youtube.rhtml")

def combine_arrays array1, array2
    array1 ||= []
    array2 ||= []
    raise "mismatch start with end count #{array1} #{array2}" unless array1.length == array2.length
    out = []
    array1.each_with_index{|start, idx|
      start = translate_string_to_seconds start
      endy = translate_string_to_seconds array2[idx]
      out << "[#{start},#{endy}]"
      raise "bad #{endy} < #{start}"  unless endy > start
    }
    out
end

def control_youtube
    # do my own parsing, rails shmails too ugly for multiples
    incoming_params = CGI.parse(request.url.split('?')[1] || '')
    logger.info "got #{incoming_params.inspect} #{params} #{params['mute_start']} #{incoming_params.inspect}"
    @mutes = combine_arrays incoming_params['mute_start'], incoming_params['mute_end']
    @splits = combine_arrays incoming_params['skip_start'], incoming_params['skip_end']
    @video_id = incoming_params['youtube_video_id']
    @should_loop = incoming_params['loop'] == '1' ? '0' : '0'
    render :action => :control_youtube
end

  def translate_string_to_seconds s
    if s.is_a? Numeric
      return s.to_f # easy out.
    end
    
    s = s.strip
    total = 0.0
    seconds = nil
    seconds = s.split(":")[-1]
    raise 'does not look like a timestamp? ' + seconds.inspect unless seconds =~ /^\d+(|[,.]\d+)$/
    seconds.gsub!(',', '.')
    total += seconds.to_f
    minutes = s.split(":")[-2] || "0"
    total += 60 * minutes.to_i
    hours = s.split(":")[-3] || "0"
    total += 60* 60 * hours.to_i
    total
  end

end
