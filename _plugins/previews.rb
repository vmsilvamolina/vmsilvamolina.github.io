require 'fileutils'
require 'imgkit'

module Previews
  def self.process(site, payload)
    # Use absolute path for the previews directory
    preview_dir = File.join(Dir.pwd, 'assets', 'images', 'previews')
    
    # Ensure the directory exists
    FileUtils.mkdir_p(preview_dir) rescue puts "Error creating directory: #{preview_dir}"
    
    # Generate the previews
    site.collections['posts'].docs.each do |p|
      # Get the slug from the post
      slug = p.data['slug']
      next if slug.nil? || slug.empty?
      
      # Define the file paths
      tmp_path = "/tmp/#{slug}.png"
      final_path = File.join(preview_dir, "#{slug}.png")
      
      # Skip if it already exists
      if File.exist?(final_path)
        next
      end
      
      puts "Creating preview for: #{slug}"
      
      begin
        # Generate HTML for the image
        html = <<-HTML
        <!DOCTYPE HTML>
        <html>
          <head>
            <meta charset='utf-8' />
          </head>
          <body>
            <div class='box'>
              <div class='title'>
                  <h2># #{p.data['title']}</h2>
              </div>
              <div class='footer'>
                  <h3>by #{p.data['author'] || 'Author'}</h3>
              </div>
            </div>
          </body>
        </html>
        HTML
        
        # Create the IMGKit object
        kit = IMGKit.new(html, {
          zoom: 1,
          quality: 100,
          width: 600,
          height: 330
        })
        
        # Add CSS if it exists
        css_path = File.join(Dir.pwd, 'assets', 'css', 'previews.css')
        if File.exist?(css_path)
          kit.stylesheets << css_path
        else
          puts "WARNING: CSS file not found at #{css_path}"
        end
        
        # First save to temporary directory
        puts "Saving to temporary file: #{tmp_path}"
        File.open(tmp_path, 'wb') do |file|
          file << kit.to_img(:png)
        end
        
        # Verify it was created correctly
        if File.exist?(tmp_path)
          # Copy to final directory
          puts "Copying to final destination: #{final_path}"
          FileUtils.cp(tmp_path, final_path)
          
          # Optimize if pngquant is available
          if system("which pngquant > /dev/null 2>&1")
            puts "Optimizing image with pngquant"
            `pngquant #{final_path} -o #{final_path} -f`
          else
            puts "pngquant is not installed, skipping optimization"
          end
        else
          puts "ERROR: Could not create temporary file #{tmp_path}"
        end
        
      rescue => e
        puts "ERROR processing #{slug}: #{e.message}"
        puts e.backtrace.join("\n")
      end
    end
  end
end

# Register the hook
Jekyll::Hooks.register :site, :post_write do |site, payload|
  Previews.process(site, payload)
end