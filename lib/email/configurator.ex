defmodule Rivet.Email.Configurator do
  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      use Rivet.Utils.LazyCache

      @persist_for 600_000

      # base config for all sites
      def get_key("site", key), do: get_config_key_("site", key)

      # named site, not base
      def get_key(<<site::binary>>, key) do
        with :error <- get_config_key_("site/#{site}", key),
          do: get_config_key_("site", key)
      end

      # similarly, but for the full config
      def get_config("site"), do: get_config_("site")
      def get_config(<<name::binary>>) do
        with {:ok, sitecfg} <- get_config_("site") do
          case get_config_("site/#{name}") do
            :error -> {:ok, sitecfg}
            {:ok, namedcfg} -> deepishmerge(sitecfg, namedcfg)
          end
        end
      end

      # 1 level deep merge
      defp deepishmerge(map1, map2) do
        Map.merge(map1, map2, fn
          _, m1, m2 when is_map(m1) and is_map(m2) ->
            Map.merge(m1, m2)
          _, _, v2 -> v2
        end)
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
