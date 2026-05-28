defmodule Rivet.Email.Configurator do
  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      use Rivet.Utils.LazyCache

      def get_key(a, b), do: Rivet.Email.Configurator.get_key_(__MODULE__, a, b)
      defoverridable get_key: 2

      def get_config(a), do: Rivet.Email.Configurator.get_config_(__MODULE__, a)
      defoverridable get_config: 1
    end
  end

  @persist_for 600_000

  ##############################################################################
  # base config for all sites
  def get_key_(parent, "site", key), do: get_config_key_(parent, "site", key)

  # named site, not base
  def get_key_(parent, <<site::binary>>, key) do
    with {:error, _} <- get_config_key_(parent, site, key),
         do: get_config_key_(parent, "site", key)
  end

  # similarly, but for the full config
  def get_config_(parent, "site"), do: get_config__(parent, "site")

  def get_config_(parent, <<name::binary>>) do
    with {:error, _} <- get_config__(parent, name), do: get_config__(parent, "site")
  end

  ##########################################################################
  defp get_config_key_(parent, cfgname, key) when is_list(key) do
    with {:ok, cfg} <- get_config__(parent, cfgname),
         do: get_in_(cfg, key)
  end

  defp get_in_(cfg, key) when is_map(cfg) do
    case get_in(cfg, key) do
      nil -> {:error, :not_found}
      value -> {:ok, value}
    end
  end

  def get_config__(parent, cfgname) do
    case parent.lookup(cfgname) do
      [{_, target, _}] ->
        {:ok, target}

      _ ->
        case Rivet.Email.Template.one(name: "//CONFIG/#{cfgname}") do
          {:ok, c} ->
            with {:ok, data} <- Jason.decode(c.data) do
              data = Transmogrify.transmogrify(data)
              parent.insert(cfgname, data, @persist_for)
              {:ok, data}
            end

          _ ->
            {:error, "no email template for: #{cfgname}"}
        end
    end
  end
end
