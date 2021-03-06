require_relative '../spec_helper'

require 'busser/ui'

# Dummy class containing diagnostic methods approximating Thor mixins
class SneakyUI

  include Busser::UI

  attr_reader :run_args, :run_ruby_script_args
  attr_accessor :status

  def say(msg)
     msg
  end

  def run(cmd, opts)
    @run_args = [cmd, opts]
  end

  def run_ruby_script(cmd, opts)
    @run_ruby_script_args = [cmd, opts]
  end

  def exit(status)
    @died = true
    status
  end

  def died?
    @died
  end

  # these methods are technically private, so we'll avoid straight send
  # calls in the specs
  %w{banner info warn die run! run_ruby_script!}.each do |meth|
    define_method("invoke_#{meth}") { |*args| send(meth, *args) }
  end
end

# Stub that mimicks a Process::Status object
class FakeStatus

  attr_reader :exitstatus

  def initialize(success = true, exitstatus = 0)
    @success, @exitstatus = success, exitstatus
  end

  def success?
    @success
  end
end

describe Busser::UI do

  let(:ui) do
    ui = SneakyUI.new
    ui.status = FakeStatus.new(true)
    ui
  end

  it "#banner should display a formatted message" do
    ui.invoke_banner("coffee").must_equal "-----> coffee"
  end

  it "#info should display a formatted message" do
    ui.invoke_info("beans").must_equal "       beans"
  end

  it "#warn should display a formatted message" do
    ui.invoke_warn("grinder").must_equal ">>>>>> grinder"
  end

  describe "#die" do
    it "prints a message to stderr" do
      capture_stderr { ui.invoke_die("noes") }.must_equal "noes\n"
    end

    it "calls exit with 1 by default" do
      capture_stderr do
        ui.invoke_die("fail").must_equal 1
      end
    end

    it "exits with a custom exit status" do
      capture_stderr do
        ui.invoke_die("fail", 16).must_equal 16
      end
    end
  end

  describe "#run!" do

    it "calls #run with correct options" do
      ui.invoke_run!("doitpls")

      ui.run_args.must_equal([
        "doitpls",
        { :capture => false, :verbose => false}
      ])
    end

    it "returns true if command succeeded" do
      ui.invoke_run!("great-stuff").must_equal true
    end

    it "terminates the program if the command failed" do
      ui.status = FakeStatus.new(false)
      capture_stderr { ui.invoke_run!("failwhale") }

      ui.died?.must_equal true
    end

    it "terminates with the exit code of the failed command" do
      ui.status = FakeStatus.new(false, 24)

      capture_stderr do
        ui.invoke_run!("failwhale").must_equal 24
      end
    end
  end

  describe "#run_ruby_script!" do

    it "calls #run_ruby_script with correct default options" do
      ui.invoke_run_ruby_script!("theworks.rb")

      ui.run_ruby_script_args.must_equal([
        "theworks.rb",
        { :capture => false, :verbose => false }
      ])
    end

    it "calls #run_ruby_script with correct default options" do
      ui.invoke_run_ruby_script!("theworks.rb", :verbose => true)

      ui.run_ruby_script_args.must_equal([
        "theworks.rb",
        { :capture => false, :verbose => true }
      ])
    end

    it "returns true if command succeeded" do
      ui.invoke_run_ruby_script!("thewin.rb").must_equal true
    end

    it "terminates the program if the script failed" do
      ui.status = FakeStatus.new(false)
      capture_stderr { ui.invoke_run_ruby_script!("nope.rb") }

      ui.died?.must_equal true
    end

    it "terminates with the exit code of the failed script" do
      ui.status = FakeStatus.new(false, 97)

      capture_stderr do
        ui.invoke_run_ruby_script!("nadda.rb").must_equal 97
      end
    end
  end

  def capture_stderr
    original_stderr, $stderr = $stderr, StringIO.new
    yield
    $stderr.string
  ensure
    $stderr = original_stderr
  end
end
