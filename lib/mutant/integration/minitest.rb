require 'minitest'

# monkey patch for minitest
module Minitest
  # Prevent autorun from running tests when the VM closes
  #
  # Mutant needs control about the exit status of the VM and
  # the moment of test execution
  #
  # @api private
  #
  # @return [nil]
  def self.autorun
  end

end # Minitest

module Mutant
  class Integration
    # Minitest integration
    class Minitest < self
      TEST_FILE_PATTERN     = './test/**/{test_*,*_test}.rb'.freeze
      IDENTIFICATION_FORMAT = 'minitest:%s#%s'.freeze

      private_constant(*constants(false))

      # Compose a runnable with test method
      #
      # This looks actually like a missing object on minitest implementation.
      class TestCase
        include Adamantium, Concord.new(:klass, :test_method)

        # Identification string
        #
        # @return [String]
        def identification
          IDENTIFICATION_FORMAT % [klass, test_method]
        end
        memoize :identification

        # Run test case
        #
        # @param [Object] reporter
        #
        # @return [Boolean]
        def call(reporter)
          ::Minitest::Runnable.run_one_method(klass, test_method, reporter)
          reporter.passed?
        end

        # Cover expression syntaxes
        #
        # @return [Array<String>]
        def expression_syntax
          klass.cover_expression
        end

      end # TestCase

      private_constant(*constants(false))

      # Setup integration
      #
      # @return [self]
      def setup
        Pathname.glob(TEST_FILE_PATTERN)
          .map(&:to_s)
          .each(&method(:require))

        self
      end

      # Call test integration
      #
      # @param [Array<Tests>] tests
      #
      # @return [Result::Test]
      #
      # rubocop:disable MethodLength
      def call(tests)
        test_cases = tests.map(&all_tests_index.method(:fetch)).to_set

        output   = StringIO.new
        reporter = ::Minitest::SummaryReporter.new(output)
        start    = Time.now

        passed = test_cases.all? { |test| test.call(reporter) }
        output.rewind

        Result::Test.new(
          passed:  passed,
          tests:   tests,
          output:  output.read,
          runtime: Time.now - start
        )
      end

      # All tests exposed by this integration
      #
      # @return [Array<Test>]
      def all_tests
        all_tests_index.keys
      end
      memoize :all_tests

    private

      # The index of all tests to runnable test cases
      #
      # @return [Hash<Test,TestCase>]
      def all_tests_index
        all_test_cases.each_with_object({}) do |test_case, index|
          index[construct_test(test_case)] = test_case
        end
      end
      memoize :all_tests_index

      # Construct test from test case
      #
      # @param [TestCase]
      #
      # @return [Test]
      def construct_test(test_case)
        Test.new(
          id:         test_case.identification,
          expression: config.expression_parser.(test_case.expression_syntax)
        )
      end

      # All minitest test cases
      #
      # Intentional utility method.
      #
      # @return [Array<TestCase>]
      def all_test_cases
        ::Minitest::Runnable.runnables.flat_map(&method(:test_case))
      end

      # Turn a minitest runnable into its test cases
      #
      # Intentional utility method.
      #
      # @param [Object] runnable
      #
      # @return [Array<TestCase>]
      def test_case(runnable)
        runnable.runnable_methods.map { |method| TestCase.new(runnable, method) }
      end

    end # Minitest
  end # Integration
end # Mutant
