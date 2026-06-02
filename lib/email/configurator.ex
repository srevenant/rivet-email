defmodule Rivet.Email.Configurator do
  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      use Rivet.Utils.LazyCache

      def conf(grp, key, site \\ "") do
        get_through({site, grp, key}, fn _ ->
          with {:ok, %{value: value}} <- Rivet.Email.Config.one(site: site, group: grp, key: key),
            do: {:ok, value}
        end)
      end

      def conf!(grp, key, site \\ "") do
        case conf(grp, key, site) do
          {:ok, value} -> value
          {:error, :not_found} -> raise "email config not found: #{site}.#{grp}.#{key}"
        end
      end

      def load_site(site) do
        get_through(site, fn _ ->
          Rivet.Email.Config.load_site(site)
        end)
      end
    end
  end
end
