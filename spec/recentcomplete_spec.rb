require 'spec_helper'

module MatchHelper
  def matches(find_start, keyword_base)
    result = vim.echo("recentcomplete#matches(#{find_start}, '#{keyword_base}')")
  end

  def words(words)
    "[#{words.map { |word| "{'word': '#{word}', 'menu': '~'}" }.join(", ")}]"
  end

  def git(*args, date: :now)
    env = {}
    if date != :now
      env["GIT_COMMITTER_DATE"] = date
    end
    raise unless system(env, "git", *args.map(&:to_s))
  end
end

describe "recentcomplete#matches without git" do
  include MatchHelper
  after do
    vim.command("bwipeout!")
  end

  it "includes unsaved keywords" do
    vim.edit 'foo.rb'
    vim.insert("hello\n")
    vim.write

    vim.insert("world")

    expect(matches(0, "")).to eq(words(%w[world]))
  end
end

describe "recentcomplete#matches" do
  include MatchHelper
  let(:long_past) { "Wed Feb 16 14:00 2011 +0100" }

  before do
    git :init
    git :commit, "--allow-empty", "-m", "Initial Commit", date: long_past
  end

  after do
    vim.command("bwipeout!")
  end

  it "includes matches from the current, unsaved buffer" do
    vim.edit 'foo.rb'
    vim.insert("hello\nhowdy")

    expect(matches(0, "h")).to eq(words %w[hello howdy])
  end

  it "includes matches from other untracked files" do
    write_file('bar.rb', <<-EOF)
      unicorn
        fantasy
    EOF
    vim.edit 'foo.rb'

    expect(matches(0, "")).to eq(words %w[unicorn fantasy])
  end

  it "includes matches from recently committed files" do
    write_file('bar.rb', <<-EOF)
      magic
        kingdom
    EOF
    git :add, "bar.rb"
    git :commit, "-am", "commit"

    vim.edit 'foo.rb'

    expect(matches(0, "")).to eq(words %w[kingdom magic])
  end

  it "includes matches from uncommitted changes in other files" do
    write_file('bar.rb', <<-EOF)
      magic
        kingdom
    EOF
    git :add, "bar.rb"
    git :commit, "-am", "commit", date: long_past

    write_file('bar.rb', <<-EOF)
      magic
        kingdom
      disneyland
    EOF

    vim.edit 'foo.rb'

    expect(matches(0, "")).to eq(words %w[disneyland])
  end

  it "does not include matches from committed files in the past" do
    write_file('bar.rb', <<-EOF)
      sad
      panda
    EOF
    git :add, "bar.rb"
    git :commit, "-am", "commit", date: long_past

    vim.edit 'foo.rb'

    expect(matches(0, "")).to eq(words %w[])
  end
end
