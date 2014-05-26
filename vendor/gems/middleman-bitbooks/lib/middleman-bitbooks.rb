# Require core library
require 'middleman-core'
require 'middleman-bitbooks/version'

# Register extensions which can be activated
# Make sure we have the version of Middleman we expect
# Name param may be omited, it will default to underscored
# version of class name

::Middleman::Extensions.register(:linkswap) do
    require "middleman-bitbooks/linkswap"
      ::Middleman::Bitbooks::Linkswap
end

# Register each new extensions here, and add a new
# file into the middleman-bitbooks folder, containing the
# extension code. See linkswap.rb for an example.
