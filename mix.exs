defmodule Expr.Mixfile do
  use Mix.Project

  def project do
    [app: :expr,
     version: "1.0.0",
     elixir: "~> 1.0",
     deps: deps,
     test_coverage: [tool: ExCoveralls],
     aliases: aliases]
  end

  def application do
    [applications: [:logger]]
  end

  defp aliases do
    [bench: [&set_bench_env/1, "bench"]]
  end

  defp set_bench_env(_) do
    Mix.env(:bench)
  end

  defp deps do
    [{:excoveralls, "~> 0.3", only: [:dev, :test]},
     {:benchfella, "~> 0.2.0", only: [:dev, :test, :bench]}]
  end
end