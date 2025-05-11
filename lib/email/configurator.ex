defmodule Rivet.Email.Configurator do
  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      use Rivet.Utils.LazyCache

      @persist_for 600_000

      # base config for all sites
      def get_key("site", key), do: get_config_key_("site", key)

      # named site, not base
      def get_key(<<site::binary>>, key) do
        with :error <- get_config_key_(site, key),
          do: get_config_key_("site", key)
      end

      # similarly, but for the full config
      def get_config("site"), do: get_config_("site")
      def get_config(<<name::binary>>) do
        with :error <- get_config_(name), do: get_config_("site")
      end

      ##########################################################################
      defp get_config_key_(cfgname, key) do
        with {:ok, cfg} <- get_config_(cfgname),
          do: get_in_(cfg, key)
      end

      defp get_in_(cfg, key) when is_map(cfg) do
        case get_in(cfg, key) do
          nil -> :error
          value -> {:ok, value}
        end
      end


      def get_config_(cfgname) do
        case lookup(cfgname) do
          [{_, target, _}] ->
            {:ok, target}

          _ ->
            case Rivet.Email.Template.one(name: "//CONFIG/#{cfgname}") do
              {:ok, c} ->
                with {:ok, data} <- Jason.decode(c.data) do
                  data = Transmogrify.transmogrify(data)
                  insert(cfgname, data, @persist_for)
                  {:ok, data}
                end

              _ ->
                :error
            end
        end
      end
    end
  end
end
