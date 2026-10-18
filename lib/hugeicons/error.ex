defmodule Hugeicons.Error do
  @moduledoc """
  Raised when the icons cannot be downloaded, verified or read.

  Messages never include the license key.
  """
  defexception [:message]

  @type t() :: %__MODULE__{message: String.t()}
end
