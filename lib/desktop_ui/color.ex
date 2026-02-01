defmodule DesktopUI.Color do
  @moduledoc """
  Color manipulation and validation for DesktopUI.

  This module provides color normalization, conversion, and blending
  utilities used throughout the DesktopUI graphics system.

  ## Color Formats

  The module supports multiple color input formats:

  * **Named colors** - `:black`, `:white`, `:red`, `:green`, `:blue`, etc.
  * **RGBA tuples** - `{r, g, b, a}` where each component is 0-255
  * **RGB tuples** - `{r, g, b}` (alpha defaults to 255)
  * **Map with keys** - `%{r: 0..255, g: 0..255, b: 0..255, a: 0..255}`
  * **Hex strings** - `"#RGB"`, `"#RRGGBB"`, or `"#RRGGBBAA"`
  * **Grayscale** - Single integer 0-255

  All color formats are normalized to `{r, g, b, a}` tuples.

  ## Examples

      iex> Color.normalize(:red)
      {255, 0, 0, 255}

      iex> Color.normalize({100, 150, 200})
      {100, 150, 200, 255}

      iex> Color.normalize("#FF0000")
      {255, 0, 0, 255}

      iex> Color.to_uint32({255, 0, 0, 255})
      4278190335

  """

  import Bitwise

  @type color :: {byte(), byte(), byte(), byte()}
  @type color_input ::
          color_name()
          | color()
          | {byte(), byte(), byte()}
          | %{r: integer(), g: integer(), b: integer(), a: integer()}
          | String.t()
          | byte()

  @type color_name ::
          :black
          | :white
          | :red
          | :green
          | :blue
          | :yellow
          | :cyan
          | :magenta
          | :transparent
          | :gray
          | :dark_gray
          | :light_gray
          | :orange
          | :purple
          | :pink

  # Named colors map
  @named_colors %{
    black: {0, 0, 0, 255},
    white: {255, 255, 255, 255},
    red: {255, 0, 0, 255},
    green: {0, 255, 0, 255},
    blue: {0, 0, 255, 255},
    yellow: {255, 255, 0, 255},
    cyan: {0, 255, 255, 255},
    magenta: {255, 0, 255, 255},
    transparent: {0, 0, 0, 0},
    gray: {128, 128, 128, 255},
    dark_gray: {64, 64, 64, 255},
    light_gray: {192, 192, 192, 255},
    orange: {255, 165, 0, 255},
    purple: {128, 0, 128, 255},
    pink: {255, 192, 203, 255}
  }

  @doc """
  Normalize a color input to an RGBA tuple `{r, g, b, a}`.

  Returns `{:error, reason}` if the color format is invalid.

  ## Examples

      iex> Color.normalize(:red)
      {255, 0, 0, 255}

      iex> Color.normalize({100, 150, 200})
      {100, 150, 200, 255}

      iex> Color.normalize({100, 150, 200, 128})
      {100, 150, 200, 128}

      iex> Color.normalize("%{r: 255, g: 0, b: 0, a: 255}")
      {255, 0, 0, 255}

      iex> Color.normalize("#FF0000")
      {255, 0, 0, 255}

      iex> Color.normalize(128)
      {128, 128, 128, 255}

  """
  @spec normalize(color_input()) :: color() | {:error, String.t()}
  def normalize(color) when is_map(color) do
    has_keys =
      Map.has_key?(color, :r) and Map.has_key?(color, :g) and
        Map.has_key?(color, :b) and Map.has_key?(color, :a)

    with true <- has_keys,
         r when is_integer(r) and r >= 0 and r <= 255 <- Map.get(color, :r),
         g when is_integer(g) and g >= 0 and g <= 255 <- Map.get(color, :g),
         b when is_integer(b) and b >= 0 and b <= 255 <- Map.get(color, :b),
         a when is_integer(a) and a >= 0 and a <= 255 <- Map.get(color, :a) do
      {r, g, b, a}
    else
      _ -> {:error, "Invalid color map. Expected %{r: 0..255, g: 0..255, b: 0..255, a: 0..255}"}
    end
  end

  def normalize(color) when is_tuple(color) do
    case color do
      {r, g, b, a}
      when is_integer(r) and r >= 0 and r <= 255 and
             is_integer(g) and g >= 0 and g <= 255 and
             is_integer(b) and b >= 0 and b <= 255 and
             is_integer(a) and a >= 0 and a <= 255 ->
        {r, g, b, a}

      {r, g, b}
      when is_integer(r) and r >= 0 and r <= 255 and
             is_integer(g) and g >= 0 and g <= 255 and
             is_integer(b) and b >= 0 and b <= 255 ->
        {r, g, b, 255}

      _ ->
        {:error, "Invalid color tuple. Expected {r, g, b, a} or {r, g, b} with values 0-255"}
    end
  end

  def normalize(color) when is_atom(color) do
    case Map.get(@named_colors, color) do
      nil ->
        {:error, "Unknown named color: #{color}. Available: #{inspect(Map.keys(@named_colors))}"}

      rgba ->
        rgba
    end
  end

  def normalize(color) when is_binary(color), do: parse_hex_color(color)

  def normalize(gray) when is_integer(gray) and gray >= 0 and gray <= 255 do
    {gray, gray, gray, 255}
  end

  def normalize(_), do: {:error, "Invalid color format"}

  @doc """
  Convert an RGBA color tuple to Uint32 format (0xRRGGBBAA).

  This format is used by SDL2 for color values.

  ## Examples

      iex> Color.to_uint32({255, 0, 0, 255})
      4278190335

      iex> Color.to_uint32({0, 255, 0, 255})
      16711935

  """
  @spec to_uint32(color()) :: non_neg_integer()
  def to_uint32({r, g, b, a}) do
    (r <<< 24) + (g <<< 16) + (b <<< 8) + a
  end

  @doc """
  Blend two colors with a given alpha ratio (0.0-1.0).

  When alpha is 0.0, returns the first color.
  When alpha is 1.0, returns the second color.
  Values between blend the two colors linearly.

  ## Examples

      iex> Color.blend({0, 0, 0, 255}, {255, 255, 255, 255}, 0.5)
      {128, 128, 128, 255}

      iex> Color.blend({255, 0, 0, 255}, {0, 0, 255, 255}, 0.5)
      {128, 0, 128, 255}

  """
  @spec blend(color(), color(), float()) :: color()
  def blend({r1, g1, b1, a1}, {r2, g2, b2, a2}, alpha)
      when is_number(alpha) and alpha >= 0.0 and alpha <= 1.0 do
    {
      round(r1 * (1 - alpha) + r2 * alpha),
      round(g1 * (1 - alpha) + g2 * alpha),
      round(b1 * (1 - alpha) + b2 * alpha),
      round(a1 * (1 - alpha) + a2 * alpha)
    }
  end

  @doc """
  Get the list of available named colors.

  ## Examples

      iex> :black in Color.named_colors()
      true

      iex> :not_a_color in Color.named_colors()
      false

  """
  @spec named_colors() :: [color_name()]
  def named_colors do
    Map.keys(@named_colors)
  end

  @doc """
  Check if a color name is valid.

  ## Examples

      iex> Color.valid_name?(:red)
      true

      iex> Color.valid_name?(:not_a_color)
      false

  """
  @spec valid_name?(atom()) :: boolean()
  def valid_name?(name) when is_atom(name) do
    Map.has_key?(@named_colors, name)
  end

  def valid_name?(_), do: false

  # Parse hex color string to RGBA tuple
  defp parse_hex_color("#" <> hex) do
    hex = String.downcase(hex)

    normalized =
      case String.length(hex) do
        3 -> parse_3digit_hex(hex)
        6 -> parse_6digit_hex(hex)
        8 -> parse_8digit_hex(hex)
        _ -> {:error, "Invalid hex color format. Expected #RGB, #RRGGBB, or #RRGGBBAA"}
      end

    case normalized do
      {:error, _} = error -> error
      rgba -> rgba
    end
  end

  defp parse_hex_color(_), do: {:error, "Invalid hex color format. Expected #RGB, #RRGGBB, or #RRGGBBAA"}

  defp parse_3digit_hex(<<r::utf8, g::utf8, b::utf8>>) do
    with {r_int, ""} <- Integer.parse(String.duplicate(<<r>>, 2), 16),
         {g_int, ""} <- Integer.parse(String.duplicate(<<g>>, 2), 16),
         {b_int, ""} <- Integer.parse(String.duplicate(<<b>>, 2), 16) do
      {r_int, g_int, b_int, 255}
    else
      _ -> {:error, "Invalid 3-digit hex color"}
    end
  end

  defp parse_3digit_hex(_), do: {:error, "Invalid 3-digit hex color"}

  defp parse_6digit_hex(<<r1::utf8, r2::utf8, g1::utf8, g2::utf8, b1::utf8, b2::utf8>>) do
    with {r_int, ""} <- Integer.parse(<<r1, r2>>, 16),
         {g_int, ""} <- Integer.parse(<<g1, g2>>, 16),
         {b_int, ""} <- Integer.parse(<<b1, b2>>, 16) do
      {r_int, g_int, b_int, 255}
    else
      _ -> {:error, "Invalid 6-digit hex color"}
    end
  end

  defp parse_6digit_hex(_), do: {:error, "Invalid 6-digit hex color"}

  defp parse_8digit_hex(<<r1::utf8, r2::utf8, g1::utf8, g2::utf8, b1::utf8, b2::utf8, a1::utf8, a2::utf8>>) do
    with {r_int, ""} <- Integer.parse(<<r1, r2>>, 16),
         {g_int, ""} <- Integer.parse(<<g1, g2>>, 16),
         {b_int, ""} <- Integer.parse(<<b1, b2>>, 16),
         {a_int, ""} <- Integer.parse(<<a1, a2>>, 16) do
      {r_int, g_int, b_int, a_int}
    else
      _ -> {:error, "Invalid 8-digit hex color"}
    end
  end

  defp parse_8digit_hex(_), do: {:error, "Invalid 8-digit hex color"}
end
