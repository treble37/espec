defmodule Mix.Utils.StaleCompatible do
  @moduledoc """
  This module was written to deal with the incompatibilies between Elixir <= 1.9
  and the release of Elixir 1.10. It is expected to eventually go away (hopefully).
  """

  defmacro __using__(_args) do
    quote do
      def parallel_require_callbacks(pid, cwd),
        do:
          Mix.Utils.StaleCompatible.parse_version()
          |> Mix.Utils.StaleCompatible.parallel_require_callbacks(pid, cwd)
    end
  end

  def parallel_require_callbacks(%Version{major: 1, minor: minor} = version, pid, cwd)
      when minor >= 9,
      do: [
        each_module: &each_module(version, pid, cwd, &1, &2, &3),
        each_file: &each_file(pid, &1, &2)
      ]

  def parallel_require_callbacks(%Version{major: 1, minor: minor} = version, pid, cwd)
      when minor >= 6 and minor < 9 do
    [each_module: &each_module(version, pid, cwd, &1, &2, &3)]
  end

  def parallel_require_callbacks(_, _, _),
    do: {:error, "Your version of Elixir #{System.version()} cannot support the stale feature"}

  def parse_version do
    System.version()
    |> Version.parse()
    |> case do
      {:ok, version} -> version
      :error -> :error
    end
  end

  ## ParallelRequire callback: Handled differently depending on Elixir version

  defp each_module(%Version{major: 1, minor: minor}, pid, cwd, file, module, _binary)
       when minor >= 9 do
    quote bind_quoted: [pid: pid, cwd: cwd, file: file, module: module] do
      external = get_external_resources(module, cwd)

      if external != [] do
        Agent.update(pid, fn sources ->
          file = Path.relative_to(file, cwd)
          {source, sources} = List.keytake(sources, file, source(:source))
          [source(source, external: external ++ source(source, :external)) | sources]
        end)
      end

      :ok
    end
  end

  defp each_module(%Version{major: 1, minor: minor}, pid, cwd, source, module, _binary)
       when minor >= 6 and minor < 9 do
    quote bind_quoted: [pid: pid, cwd: cwd, source: source, module: module] do
      {compile_references, struct_references, runtime_references} =
        Kernel.LexicalTracker.remote_references(module)

      external = get_external_resources(module, cwd)
      source = Path.relative_to(source, cwd)

      Agent.cast(pid, fn sources ->
        external =
          case List.keyfind(sources, source, source(:source)) do
            source(external: old_external) -> external ++ old_external
            nil -> external
          end

        new_source =
          source(
            source: source,
            compile_references: compile_references ++ struct_references,
            runtime_references: runtime_references,
            external: external
          )

        List.keystore(sources, source, source(:source), new_source)
      end)
    end
  end

  defp each_file(pid, file, lexical) do
    quote bind_quoted: [pid: pid, file: file, lexical: lexical] do
      Agent.update(pid, fn sources ->
        case List.keytake(sources, file, source(:source)) do
          {source, sources} ->
            {compile_references, struct_references, runtime_references} =
              Kernel.LexicalTracker.remote_references(lexical)

            source =
              source(
                source,
                compile_references: compile_references ++ struct_references,
                runtime_references: runtime_references
              )

            [source | sources]

          nil ->
            sources
        end
      end)
    end
  end

  defp get_external_resources(module, cwd) do
    for file <- Module.get_attribute(module, :external_resource), do: Path.relative_to(file, cwd)
  end
end
