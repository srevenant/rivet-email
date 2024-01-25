defmodule Rivet.Email.Configurator do
  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      use Rivet.Utils.LazyCache

      @persist_for 600_000

      def get({name, nil}), do: get_(name)

      def get({name, site}) do
        case get_("#{name}/#{site}") do
          {:ok, _} = pass -> pass
          _ -> get_(name)
        end
      end

      def get(name), do: get_(name)

      defp get_(name) do
        case lookup(name) do
          [{_, target, _}] -> {:ok, target}
          _ ->
            case Rivet.Email.Template.one(name: "//CONFIG/#{name}") do
              {:ok, c} ->
                with {:ok, data} <- Jason.decode(c.data) do
                  data = Transmogrify.transmogrify(data)
                  insert(name, data, @persist_for)
                  {:ok, data}
                end

              _ ->
                {:error, :not_found}
            end
        end
      end
    end
  end
end
