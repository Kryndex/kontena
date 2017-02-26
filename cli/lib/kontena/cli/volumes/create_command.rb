
module Kontena::Cli::Volume
  class CreateCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions


    banner "Creates a volume"
    parameter 'NAME', 'Volume name'

    option '--driver', 'DRIVER', 'Volume driver to be used', default: 'local'
    option '--driver-opt', 'DRIVER_OPT', 'Volume driver options', multivalued: true
    option '--scope', 'SCOPE', 'Volume scope', default: 'instance-private'

    requires_current_master
    requires_current_master_token

    def execute
      volume = {
        name: name,
        scope: scope,
        driver: driver,
        driver_opts: parse_driver_opts
      }
      spinner "Creating volume #{pastel.cyan(name)} " do
        create_volume(volume)
      end
    end

    def parse_driver_opts
      opts = {}
      driver_opt_list.each do |opt|
        opts.merge Hash[opt.split '=']
      end
      opts
    end

    def create_volume(volume)
      client.post("volumes/#{current_grid}", volume)
    end
  end
end