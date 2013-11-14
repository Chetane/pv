require 'thor'

module Pv
  class Command < Thor
    include Thor::Actions

    default_task :log
    desc :log,  "Show every story assigned to you on this project."
    def log
      Pv.tracker.stories.each do |from_data|
        preview Story.new(from_data)
      end
    end

    desc "show [STORY_ID]", "Show the full text and attributes of a story on this project."
    def show story_id=''
      story_id = prompt_story(Pv.tracker.stories) if story_id.blank?
      sha = Digest::HMAC.hexdigest story_id.to_s, Time.now.to_s, Digest::SHA1
      story = Story.find(story_id)

      if ENV['PAGER']
        file = Tempfile.new("story-#{sha}")
        file.write story.render
        file.close
        system "$PAGER #{file.path}"
        file.unlink
      else
        view story
      end
    end

    desc "score [STORY_ID] [POINTS]", "Assign points to a story"
    def score story_id='', points=''
      story_id = prompt_story(Pv.tracker.stories) if story_id.blank?
      story = Story.find(story_id)
      points = prompt_points if points.blank?
      story.point_scale(points)
      say "\n  Assigned #{points} to story [#{story.id}] #{story.name}"
    end

    desc "edit STORY_ID STATUS", "Edit a story's status on this project."
    #method_option :message, default: "", alias: 'm'
    def edit story_id, status
      story = Story.find(story_id) or raise "Error: Story not found"

      if story.update(status)
        say "\n  #{status.titleize} story ##{story_id}\n"
      else
        say "  Error: Story did not update."
      end
    end

    %w(start finish deliver accept reject restart).each do |status|
      desc "#{status} [STORY_ID]", "#{status.titleize} a story on this project."
      define_method(status) do |story_id=''|
        story_id = prompt_story(Pv.tracker.stories) if story_id.blank?
        edit(story_id, "#{status}ed")
      end
    end

    desc "create [{bug|feature|chore}] [NAME] [DESCRIPTION] [ASSIGNED TO]", "Create a new story on this project"
    method_option :assign_to
    def create type=nil, name=nil, description='', owned_by=''

      type = ask("\n  Which type of story?", :limited_to => ['bug', 'feature', 'chore']) if type.nil?
      if name.nil?
        name = ask('  Story name?')
        description = ask('  Story description?')
        owned_by = ask('  Assigned to?')
      end

      with_attributes = options.merge(story_type: type, name: name)
      with_attributes[:owned_by] = owned_by unless owned_by.blank?
      with_attributes[:description] = description unless description.blank?

      story = Story.create with_attributes

      if story.saved?
        say "Created #{type.titleize} ##{story.id}: '#{name}'"
      else
        say "Error saving #{type} with '#{name}'"
      end
    end

    desc :help, "Show all commands"
    def help
      say IO.read("#{Pv.root}/lib/templates/help.txt")
      super
    end

    desc "open STORY_ID", "Open this Pivotal story in a browser"
    def open story_id=''
      story_id = prompt_story(Pv.tracker.stories) if story_id.blank?
      run "open https://www.pivotaltracker.com/story/show/#{story_id}"
    end

  private
    no_tasks do
      def prompt_points
        index = ask("\n  How many points to assign?", :limited_to => ['0', '1', '2', '3', '5', '8'])
        index.to_i
      end

      def prompt_story(stories)

        say set_color("\n  You have the following stories:\n", Thor::Shell::Color::WHITE)

        stories.each_with_index do |story, index|
          out = set_color("    #{index}", Thor::Shell::Color::BLUE)
          out << set_color(" => ", Thor::Shell::Color::WHITE)
          out << set_color("#{story.id}", Thor::Shell::Color::YELLOW)
          out << set_color(' [', Thor::Shell::Color::BLUE)
          8.times { |i|  out << set_color((((i + 1) <= story.estimate.to_i) ? '*' : ' '), Thor::Shell::Color::BLUE) }
          out << set_color(']',Thor::Shell::Color::BLUE)
          out << set_color(" #{story.current_state} ", Thor::Shell::Color::BLUE)
          out << "#{story.name} - "
          out << set_color(story.requested_by, Thor::Shell::Color::YELLOW)

          say out
        end

        index = ask("\n  Which story do you want?")
        stories[index.to_i].id
      end

      def preview story
        id = set_color "#{story.id}", Thor::Shell::Color::YELLOW
        author = set_color story.requested_by, Thor::Shell::Color::YELLOW
        status = set_color "#{story.current_state}", Thor::Shell::Color::BLUE
        estimate = story.estimate.to_i

        star = '['
        8.times { |i|  star << (((i + 1) <= estimate) ? '*' : ' ') }
        star << ']'
        status = set_color(" #{star} ", Thor::Shell::Color::BLUE) + status

        name = set_color story.name, Thor::Shell::Color::WHITE
        prefix = "* #{id}" + status



        say "  #{prefix} #{name} #{author}"
      end

      def view story
        indent = "  "
        out = "\n#{indent}"
        out << set_color("#{story.story_type.titleize} #{story.id} - #{story.name} (#{story.estimate} points)", Thor::Shell::Color::YELLOW)
        out << set_color("\n\n#{indent}#{indent}Requested By: ", Thor::Shell::Color::BLUE)
        out << set_color(story.requested_by, Thor::Shell::Color::YELLOW)
        out << set_color("\n#{indent}#{indent}Assigned To: ", Thor::Shell::Color::BLUE)
        out << set_color(story.owned_by, Thor::Shell::Color::YELLOW)
        out << set_color("\n#{indent}#{indent}Status: ", Thor::Shell::Color::BLUE)
        out << set_color(story.current_state.upcase, Thor::Shell::Color::YELLOW)
        out << "\n\n#{indent}"
        out << set_color(story.description.gsub("\n", "\n#{indent}"),  Thor::Shell::Color::WHITE)
        out << "\n\n"

        say out
      end
    end
  end
end
