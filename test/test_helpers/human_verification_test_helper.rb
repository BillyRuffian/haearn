require 'rspec/mocks'

module HumanVerificationTestHelper
  include RSpec::Mocks::ExampleMethods

  def with_verified_human
    RSpec::Mocks.with_temporary_scope do
      allow(TurnstileVerifier).to receive(:call).and_return(:verified)
      yield
    end
  end
end
