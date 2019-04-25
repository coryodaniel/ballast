defmodule Ballast.Logger do
  @moduledoc """
  Pass through error logger. Logs errors and returns input.
  """
  require Logger

  @spec error(:error) :: :error
  def error(:error) do
    Logger.error("Unknown error")
    :error
  end

  @spec error({:error, String.t() | atom()}) :: {:error, String.t() | atom()}
  def error({:error, msg} = err) when is_atom(msg) or is_binary(msg) do
    Logger.error("Error: #{msg}")
    err
  end

  @spec error({:error, HTTPoison.Error.t()}) :: {:error, HTTPoison.Error.t()}
  def error({:error, %HTTPoison.Error{reason: reason}} = err) do
    Logger.error("HTTPoison Error: #{reason}")
    err
  end

  @spec error({:error, Tesla.Env.t()}) :: {:error, Tesla.Env.t()}
  def error({:error, %Tesla.Env{status: status}} = err) do
    Logger.error("Tesla Error: #{status}")
    err
  end
end
