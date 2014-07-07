require 'rake'
require 'json'
require 'cucumber'

module CSL
  module TestSuite

    NON_STANDARD = %{
      quotes_PunctuationWithInnerQuote            # replaces single quotes and apostrophes
      sort_SubstituteTitle                        # ---
      substitute_SuppressOrdinaryVariable         # citeproc-js bug?
      sort_FamilyOnly                             # invalid CSL (no layout) / ANZ after Aardvark?
      name_ParticleCaps3                          # " in family name
      testers_SecondAutoGeneratedZoteroPluginTest # uses <sc> for small-caps
      name_ParticleCaps2                          # capitalizes particle of first name
      parallel_HackedChicago                      # combines legal cases
      parallel_Bibliography                       # ---
      magic_SecondFieldAlign                      #
      magic_CitationLabelInBibliography           # Citation labels
      locale_TermInSort                           # MLZ
      label_EditorTranslator1                     # ?
      display_SecondFieldAlignMigratePunctuation  # format
      bibsection_Select                           # categories / collection variable
      flipflop_ItalicsWithOk                      # HTML in input
      flipflow_ItalicsWithOkAndTextcase           # ---
      variables_TitleShortOnShortTitleNoTitle     # converts shortTitle to title-short
      textcase_Uppercase                          # no-case input markup
      textcase_TitleCapitalization                # ---
      textcase_SentenceCapitalization             # ---
      textcase_Lowercase                          # ---
      textcase_CapitalizeFirstWithDecor           # ---
      textcase_CapitalizeFirst                    # ---
      textcase_CapitalizeAll                      # ---
      textcase_SkipNameParticlesInTitleCase       #
    }

    module_function

    def load(file)
      JSON.parse(File.open(file, 'r:UTF-8').read)
    end

    def tags_for(json, feature, name)
      tags = []

      tags << "@#{json['mode']}"
      tags << "@#{feature}"

      tags << '@bibsection' if json['bibsection']
      tags << '@bibentries' if json['bibentries']
      tags << '@citations' if json['citations']
      tags << '@citation-items' if json['citation_items']

      if NON_STANDARD.include? "#{feature}_#{name}" || feature == 'display'
        tags << '@non-standard'
      end

      tags.uniq
    end

  end
end

namespace :test do

  desc 'Fetch the citeproc-test repository and generate the JSON test files'
  task :init => [:clean] do
    system "hg clone https://bitbucket.org/bdarcus/citeproc-test test"
    system "cd test && python2.7 processor.py --grind"
  end

  desc 'Remove the citeproc-test repository'
  task :clean do
    system "rm -rf test"
  end

  desc 'Delete all generated CSL feature tests'
  task :clear do
    Dir['features/**/*'].sort.reverse.each do |path|
      unless path =~ /features\/(support|step_definitions)/
        if File.directory?(path)
          system "rmdir #{path}"
        else
          system "rm #{path}"
        end
      end
    end
  end

  desc 'Convert the processor tests to Cucumber features'
  task :convert => [:clear] do
    features = Dir['test/processor-tests/machines/*.json'].group_by { |path|
      File.basename(path).split(/_/, 2)[0]
    }

    features.each_key do |feature|
      system "mkdir features/#{feature}"

      features[feature].each do |file|
        json, name = CSL::TestSuite.load(file), File.basename(file, '.json').split(/_/, 2)[-1]

        tags = CSL::TestSuite.tags_for(json, feature, name)

        # Apply some filters
        json['result'].gsub!('&#38;', '&amp;')

        File.open("features/#{feature}/#{name}.feature", 'w:UTF-8') do |out|
          out << "Feature: #{feature}\n"
          out << "  As a CSL cite processor hacker\n"
          out << "  I want the test #{File.basename(file, '.json')} to pass\n\n"
          out << "  " << tags.join(' ') << "\n"
          out << "  Scenario: #{name.gsub(/([[:lower:]])([[:upper:]])/, '\1 \2')}\n"

          out << "    Given the following style:\n"
          out << "    \"\"\"\n"

          json['csl'].each_line do |line|
            out << '    ' << line
          end
          out << "\n    \"\"\"\n"

          out << "    And the following input:\n"
          out << "    \"\"\"\n"
          out << "    " << JSON.dump(json['input']) << "\n"
          out << "    \"\"\"\n"


          if json['abbreviations']
            out << "    And the following abbreviations:\n"
            out << "    \"\"\"\n"
            out << "    " << JSON.dump(json['abbreviations']) << "\n"
            out << "    \"\"\"\n"
          end

          if json['bibentries']
            out << "    And the following items have been cited:\n"
            out << "    \"\"\"\n"
            out << "    " << JSON.dump(json['bibentries'][-1]) << "\n"
            out << "    \"\"\"\n"
          end

          case json['mode']
          when 'citation'
            if json['citations'] # TODO
              out << "    And I have a citations input\n"
            end

            if json['citation_items']
              out << "    When I cite the following items:\n"
              out << "    \"\"\"\n"
              out << "    " << JSON.dump(json['citation_items']) << "\n"
              out << "    \"\"\"\n"
              out << "    Then the results should be:\n"

              lines = json['result'].each_line.to_a
              padding = lines.max.length

              lines.each do |line|
                out << ("      | %-#{padding}s |\n" % line.strip)
              end

            else
              out << "    When I cite all items\n"
              out << "    Then the result should be:\n"
              out << "    \"\"\"\n"
              json['result'].each_line do |line|
                out << "    " << line.strip << "\n"
              end
              out << "    \"\"\"\n"
            end


          when 'bibliography-header'
            out << "    When I render the entire bibliography\n"
            out << "    Then the bibliography's options should match:\n"

            headers = Hash[json['result'].each_line.map { |s| s.split(/:\s*/, 2) }]

            out << "      | entry-spacing | line-spacing |\n"
            out << ("      | %s             | %s            |\n" % [headers['entryspacing'].strip, headers['linespacing'].strip])

          when 'bibliography'

            if json['bibsection']
              out << "    When I render the following bibliography selection:\n"
              out << "    \"\"\"\n"
              out << "    " << JSON.dump(json['bibsection']) << "\n"
              out << "    \"\"\"\n"
            else
              out << "    When I render the entire bibliography\n"
            end

            out << "    Then the bibliography should be:\n"
            out << "    \"\"\"\n"
            json['result'].each_line do |line|
              out << '    ' << line
            end
            out << "\n    \"\"\"\n"
          end
        end
      end
    end
  end


end
