defmodule DesktopUI.Layout.Context do
  @moduledoc """
  Context for layout calculation.

  Contains the available space, parent bounds, and size constraints
  for layout calculation.

  ## Fields

  - `available_width` - Available width in pixels
  - `available_height` - Available height in pixels
  - `parent_bounds` - Parent's position and size (for relative positioning)
  - `constraints` - Size constraints (min, max, fixed sizes)

  ## Constraints

  Constraints control how a widget's size is calculated:

  - `:fixed_width` / `:fixed_height` - Override to exact pixel size
  - `:min_width` / `:min_height` - Minimum size (widget won't be smaller)
  - `:max_width` / `:max_height` - Maximum size (widget won't exceed)

  Fixed sizes take precedence over other constraints.

  ## Examples

      iex> alias DesktopUI.Layout.Context
      iex> Context.new(800, 600)
      %Context{available_width: 800, available_height: 600, ...}

      iex> alias DesktopUI.Layout.Context
      iex> Context.new(800, 600, constraints: [min_width: 100])
      %Context{available_width: 800, ..., constraints: %{min_width: 100}}

  """

  defstruct [:available_width, :available_height, :parent_bounds, :constraints]

  @type t :: %__MODULE__{
          available_width: pos_integer(),
          available_height: pos_integer(),
          parent_bounds: DesktopUI.Layout.bounds(),
          constraints: constraints()
        }

  @type bounds :: %{
          x: non_neg_integer(),
          y: non_neg_integer(),
          width: pos_integer(),
          height: pos_integer()
        }

  @type constraints :: %{
          optional(:fixed_width) => pos_integer(),
          optional(:fixed_height) => pos_integer(),
          optional(:min_width) => pos_integer(),
          optional(:min_height) => pos_integer(),
          optional(:max_width) => pos_integer() | :infinity,
          optional(:max_height) => pos_integer() | :infinity
        }

  @doc """
  Creates a new layout context.

  ## Parameters

  - `available_width` - Available width in pixels
  - `available_height` - Available height in pixels
  - `opts` - Optional keyword list of options

  ## Options

  - `:parent_bounds` - Parent's bounds map with :x, :y, :width, :height
  - `:constraints` - Keyword list of size constraints

  ## Examples

      iex> Context.new(800, 600)
      %Context{available_width: 800, available_height: 600, parent_bounds: %{x: 0, y: 0, width: 800, height: 600}, constraints: %{}}

      iex> Context.new(800, 600, parent_bounds: %{x: 10, y: 10, width: 780, height: 580})
      %Context{available_width: 800, available_height: 600, parent_bounds: %{x: 10, y: 10, width: 780, height: 580}, constraints: %{}}

  """
  @spec new(pos_integer(), pos_integer(), keyword()) :: t()
  def new(available_width, available_height, opts \\ []) do
    parent_bounds = Keyword.get(opts, :parent_bounds, default_parent_bounds(available_width, available_height))
    constraints = parse_constraints(Keyword.get(opts, :constraints, []))

    %__MODULE__{
      available_width: available_width,
      available_height: available_height,
      parent_bounds: parent_bounds,
      constraints: constraints
    }
  end

  @doc """
  Adds constraints to an existing context.

  Merges new constraints with existing ones. New values override existing values.

  ## Parameters

  - `context` - The context to update
  - `constraints` - Keyword list of constraints to add

  ## Examples

      iex> ctx = Context.new(800, 600)
      iex> Context.with_constraints(ctx, min_width: 100)
      %Context{..., constraints: %{min_width: 100}}

      iex> ctx = Context.new(800, 600, constraints: [min_width: 50])
      iex> Context.with_constraints(ctx, max_width: 200)
      %Context{..., constraints: %{min_width: 50, max_width: 200}}

  """
  @spec with_constraints(t(), keyword()) :: t()
  def with_constraints(%__MODULE__{} = context, constraints) do
    new_constraints = parse_constraints(constraints)
    %{context | constraints: Map.merge(context.constraints, new_constraints)}
  end

  @doc """
  Gets the available width from the context.
  """
  @spec available_width(t()) :: pos_integer()
  def available_width(%__MODULE__{available_width: width}), do: width

  @doc """
  Gets the available height from the context.
  """
  @spec available_height(t()) :: pos_integer()
  def available_height(%__MODULE__{available_height: height}), do: height

  @doc """
  Gets the parent's X offset from the context.
  """
  @spec parent_x(t()) :: non_neg_integer()
  def parent_x(%__MODULE__{parent_bounds: bounds}), do: bounds.x

  @doc """
  Gets the parent's Y offset from the context.
  """
  @spec parent_y(t()) :: non_neg_integer()
  def parent_y(%__MODULE__{parent_bounds: bounds}), do: bounds.y

  @doc """
  Returns true if the context has a fixed width constraint.
  """
  @spec has_fixed_width?(t()) :: boolean()
  def has_fixed_width?(%__MODULE__{constraints: constraints}), do: Map.has_key?(constraints, :fixed_width)

  @doc """
  Returns true if the context has a fixed height constraint.
  """
  @spec has_fixed_height?(t()) :: boolean()
  def has_fixed_height?(%__MODULE__{constraints: constraints}), do: Map.has_key?(constraints, :fixed_height)

  # Private Functions

  defp default_parent_bounds(width, height) do
    %{x: 0, y: 0, width: width, height: height}
  end

  defp parse_constraints(constraints) when is_list(constraints) do
    Enum.into(constraints, %{})
  end

  defp parse_constraints(constraints) when is_map(constraints), do: constraints
end
