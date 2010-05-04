require 'rubygems'
require 'builder'
require 'mp3info'

# First off, where do you want to look?
root = "/Users/tom/Downloads/"
feed_title = "My Downloads"
port = 3000

# Now, are you interested only in audio files, or do you want videos too?
# I exclude PDFs because the whole concept of 'PDFcasting' is stupid and ugly and needs to die in a fire.

audio_only = true

# make our comparator - using http://www.apple.com/itunes/podcasts/specs.html
comparator = case audio_only
  when true; lambda {|i| !(i.match(/\.mp3$/i) || i.match(/\.m4a$/i)) }
  when false; lambda {|i| !(i.match(/\.mp3$/i) || i.match(/\.m4a$/i) || i.match(/\.mp4$/i) || i.match(/\.mov$/i) || i.match(/\.m4v$/i)) }
end
# Yeah, if this were LISP and not Ruby, we'd use a magical macro function to merge and Not Repeat Myself.
# But it isn't, so this will have to do. Still, I get points for lambdas right? ;)

Dir.chdir(root)
files = `find .`.split(/\n/).delete_if(&comparator)
# Note for scaredy-cats: delete_if isn't deleting the file - rather, it is part of the inherent crapness
# of Ruby. Rather than calling it 'filter' like Scala would or 'Where' like .NET does, Ruby calls it delete_if.
# It doesn't actually delete your files, it filters the list of files using the comparator function we've just defined.

# Next we need to expand all the paths, get the file data and sort them by mtime.
files.map! {|i| File.expand_path(i, root)}
files.map! {|i| {:name => i, :mtime => File.new(i).mtime, :size => File.size(i)}}
files = files.sort_by {|x| x[:mtime]}.reverse

# Now we need to extract all the metadata and turn it into an RSS item.
builder = Builder::XmlMarkup.new(:target => STDOUT, :indent => 2)
builder.rss("version" => "2.0", "xmlns:itunes" => "http://www.itunes.com/dtds/podcast-1.0.dtd") do |rss|
  rss.channel do
    rss.title(feed_title)
    rss.link("http://example.org/") # doesn't actually matter but ought to be there for validation's sake.
    description = "Stuff I've recently downloaded to ~/Downloads"
    rss.description(description)
    rss.itunes :subtitle, description #weird syntax for xmlns in builder 2.0
    rss.language('en-US') # whatever
    
    files.each do |file|
      if file[:name].match(/\.mp3$/)
        id3tag = Mp3Info.open(file[:name])
      else
        id3tag = nil
      end
      rss.item do
        rss.title(id3tag.tag.title || file[:name])
        # if the mp3 has a Comment tag in the ID3, we should just use that as the rss Description. otherwise
        # cobble one together from a ragtag bag of ID3 crapola so you've got something interesting to read on
        # yer iPod.
        unless id3tag.tag.COMM.nil? || id3tag.tag.COMM.empty?
          rss.description(id3tag.tag.COMM)
        else
          rss.description("#{id3tag.tag.artist} #{id3tag.tag.composer} #{id3tag.tag.album} #{id3tag.tag.track}")
        end
        rss.pubDate(file[:mtime].to_s) # damn RSS 2.0 for RFC 822. If you ever think about writing a data format,
          # read up on ISO 8601. It is the date-time format of sane people.
          # see http://microformats.org/wiki/iso-8601
        uri = "http://localhost:#{port.to_s}" + file[:name]
        ftype = case file[:name]
          when /\.mp3$/; "audio/mpeg"
          when /\.m4a$/; "audio/mp4"
          when /\.mp4$/; "video/mp4"
          when /\.mov$/; "video/quicktime"
          when /\.m4v$/; "video/mp4"
          when /\.pdf$/; "application/pdf"
        end
        rss.enclosure("url" => uri, "length" => file[:size].to_s, "type" => ftype)
        rss.guid(uri) # never got the point of guid's in RSS - URIs should be unique enough for everything.
      end
    end
  end
end
