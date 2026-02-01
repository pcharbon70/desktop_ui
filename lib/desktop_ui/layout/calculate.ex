defmodule DesktopUI.Layout.Calculate do
  @moduledoc """
  Layout calculation engine.

  Transforms widget trees into laid-out trees with explicit bounds.
  """

  alias DesktopUI.{Layout, Layout.Context, Layout.Box, Widget}

  @type layout_result :: {:ok, Layout.t()} | {:error, String.t()}

  @doc """
  Calculates the layout for a widget tree within the given bounds.

  Returns `{:ok, layout}` where layout contains explicit bounds,
  or `{:error, reason}` if layout fails.

  ## Parameters

  - `widget` - The widget tree to layout
  - `available_bounds` - Map with :width and :height of available space
  - `context` - Layout context with constraints (optional, uses defaults if nil)

  ## Examples

      iex> alias DesktopUI.{Layout, Widget}
      iex> widget = Widget.label("Hello")
      iex> {:ok, layout} = Layout.Calculate.calculate(widget, %{width: 800, height: 600})
      iex> layout.width > 0
      true

  """
  @spec calculate(Widget.t(), %{width: pos_integer(), height: pos_integer()}, Context.t() | nil) :: layout_result()
  def calculate(widget, available_bounds, context \\ nil)

  def calculate(%Widget{type: type} = widget, available_bounds, context) when type in [:label, :button] do
    context = normalize_context(context, available_bounds)
    layout_leaf(widget, available_bounds, context)
  end

  def calculate(%Widget{type: :container} = widget, available_bounds, context) do
    context = normalize_context(context, available_bounds)
    layout_container(widget, available_bounds, context)
  end

  def calculate(%Widget{type: type}, _available_bounds, _context) do
    {:error, "Unknown widget type: #{inspect(type)}"}
  end

  def calculate(_other, _available_bounds, _context) do
    {:error, "Not a widget"}
  end

  # Leaf Widget Layout

  defp layout_leaf(%Widget{} = widget, available_bounds, context) do
    # Extract size props from widget and merge with context constraints
    widget_constraints = extract_widget_constraints(widget, available_bounds)
    merged_constraints = Map.merge(context.constraints, widget_constraints)
    updated_context = %{context | constraints: merged_constraints}

    with {:ok, intrinsic_size} <- intrinsic_size(widget, updated_context),
         {:ok, constrained_size} <- apply_constraints(intrinsic_size, updated_context.constraints, available_bounds),
         {:ok, position} <- calculate_position(widget, constrained_size, updated_context) do
      layout = Layout.new(
        position.x,
        position.y,
        constrained_size.width,
        constrained_size.height,
        widget
      )

      {:ok, layout}
    end
  end

  # Container Layout

  defp layout_container(%Widget{props: props} = widget, available_bounds, context) do
    # Extract size props from widget and merge with context constraints
    widget_constraints = extract_widget_constraints(widget, available_bounds)
    merged_constraints = Map.merge(context.constraints, widget_constraints)
    updated_context = %{context | constraints: merged_constraints}

    layout_type = Keyword.get(props, :layout)

    case layout_type do
      :vbox ->
        layout_vbox(widget, available_bounds, updated_context)

      :hbox ->
        layout_hbox(widget, available_bounds, updated_context)

      _ ->
        # Fallback for containers without explicit layout type
        layout_container_fallback(widget, available_bounds, updated_context)
    end
  end

  # Fallback container layout (used for hbox and untyped containers)
  defp layout_container_fallback(%Widget{children: children} = widget, available_bounds, context) do
    # For now, non-vbox containers just calculate intrinsic size from children
    # Full positioning logic for hbox comes in section 3.3
    with {:ok, intrinsic_size} <- container_intrinsic_size(children, context),
         {:ok, constrained_size} <- apply_constraints(intrinsic_size, context.constraints, available_bounds),
         {:ok, position} <- calculate_position(widget, constrained_size, context) do
      layout = Layout.new(
        position.x,
        position.y,
        constrained_size.width,
        constrained_size.height,
        widget
      )

      {:ok, layout}
    end
  end

  # VBox Layout Algorithm

  defp layout_vbox(%Widget{children: children, props: props}, available_bounds, context) do
    # Extract and normalize box props using Box helper
    box_props = Box.extract_props(props)

    # Calculate available space for children (after padding)
    child_available_width = max(available_bounds.width - box_props.padding_total, 0)

    # Calculate intrinsic size for all children using Box helper
    child_intrinsic_sizes = Box.child_intrinsic_sizes(children, context)

    # Calculate intrinsic container size
    max_child_width = Enum.reduce(child_intrinsic_sizes, 0, fn size, acc -> max(acc, size.width) end)
    total_child_height = Enum.reduce(child_intrinsic_sizes, 0, fn size, acc -> acc + size.height end)
    spacing_height = box_props.spacing * max(length(children) - 1, 0)

    intrinsic_width = max_child_width + box_props.padding_total
    intrinsic_height = total_child_height + spacing_height + box_props.padding_total

    intrinsic_size = %{width: intrinsic_width, height: intrinsic_height}

    # Apply constraints to get final container size
    with {:ok, constrained_size} <- apply_constraints(intrinsic_size, context.constraints, available_bounds),
         {:ok, position} <- calculate_position(%Widget{props: props}, constrained_size, context) do

      # Layout each child (child_available_width for sizing, available_bounds.width for alignment)
      child_layouts =
        layout_vbox_children(
          children,
          child_intrinsic_sizes,
          box_props.spacing,
          box_props.padding,
          child_available_width,
          available_bounds.width,
          box_props.align,
          context
        )

      # Create container layout using Box helper
      {:ok, Box.container_layout(
        position.x,
        position.y,
        constrained_size.width,
        constrained_size.height,
        child_layouts,
        props
      )}
    end
  end

  defp layout_vbox_children(children, intrinsic_sizes, spacing, padding, child_layout_width, container_width, align, context) do
    # Layout each child vertically, accumulating y position
    {layouts, _y_offset} =
      Enum.map_reduce(
        Enum.zip(children, intrinsic_sizes),
        padding,
        fn {child, _intrinsic_size}, y_offset ->
          # Calculate child's layout - give it sufficient height
          # Use child_layout_width (accounts for padding) for child sizing
          child_available_bounds = %{width: child_layout_width, height: 10000}

          case calculate(child, child_available_bounds, context) do
            {:ok, child_layout} ->
              # Calculate x position using Box helper
              # Use container_width (full width) for alignment
              x_offset = Box.x_alignment(child_layout.width, container_width, align, padding)
              positioned_layout = %{child_layout | x: x_offset, y: y_offset}

              # Next y position = current y + child height + spacing
              new_y_offset = y_offset + child_layout.height + spacing

              {positioned_layout, new_y_offset}

            {:error, _reason} ->
              # Return failed layout using Box helper
              {Box.failed_layout(padding, y_offset, child), y_offset}
          end
        end
      )

    layouts
  end

  # HBox Layout Algorithm

  defp layout_hbox(%Widget{children: children, props: props}, available_bounds, context) do
    # Extract and normalize box props using Box helper
    box_props = Box.extract_props(props)

    # Calculate available space for children (after padding)
    child_available_height = max(available_bounds.height - box_props.padding_total, 0)

    # Calculate intrinsic size for all children using Box helper
    child_intrinsic_sizes = Box.child_intrinsic_sizes(children, context)

    # Calculate intrinsic container size (swapped width/height from VBox)
    total_child_width = Enum.reduce(child_intrinsic_sizes, 0, fn size, acc -> acc + size.width end)
    max_child_height = Enum.reduce(child_intrinsic_sizes, 0, fn size, acc -> max(acc, size.height) end)
    spacing_width = box_props.spacing * max(length(children) - 1, 0)

    intrinsic_width = total_child_width + spacing_width + box_props.padding_total
    intrinsic_height = max_child_height + box_props.padding_total

    intrinsic_size = %{width: intrinsic_width, height: intrinsic_height}

    # Apply constraints to get final container size
    with {:ok, constrained_size} <- apply_constraints(intrinsic_size, context.constraints, available_bounds),
         {:ok, position} <- calculate_position(%Widget{props: props}, constrained_size, context) do

      # Layout each child (child_available_height for sizing, available_bounds.height for alignment)
      child_layouts =
        layout_hbox_children(
          children,
          child_intrinsic_sizes,
          box_props.spacing,
          box_props.padding,
          child_available_height,
          available_bounds.height,
          box_props.align,
          context
        )

      # Create container layout using Box helper
      {:ok, Box.container_layout(
        position.x,
        position.y,
        constrained_size.width,
        constrained_size.height,
        child_layouts,
        props
      )}
    end
  end

  defp layout_hbox_children(children, intrinsic_sizes, spacing, padding, child_layout_height, container_height, align, context) do
    # Layout each child horizontally, accumulating x position
    {layouts, _x_offset} =
      Enum.map_reduce(
        Enum.zip(children, intrinsic_sizes),
        padding,
        fn {child, _intrinsic_size}, x_offset ->
          # Calculate child's layout - give it sufficient width
          # Use child_layout_height (accounts for padding) for child sizing
          child_available_bounds = %{width: 10000, height: child_layout_height}

          case calculate(child, child_available_bounds, context) do
            {:ok, child_layout} ->
              # Calculate y position using Box helper
              # Use container_height (full height) for alignment
              y_offset = Box.y_alignment(child_layout.height, container_height, align, padding)
              positioned_layout = %{child_layout | x: x_offset, y: y_offset}

              # Next x position = current x + child width + spacing
              new_x_offset = x_offset + child_layout.width + spacing

              {positioned_layout, new_x_offset}

            {:error, _reason} ->
              # Return failed layout using Box helper
              {Box.failed_layout(x_offset, padding, child), x_offset}
          end
        end
      )

    layouts
  end

  # Intrinsic Size Calculation

  @doc """
  Calculates the intrinsic (natural) size for a widget.

  For leaf widgets:
  - Label: Based on text length (character_count * char_width)
  - Button: Text size + button padding

  For containers:
  - Calculated from children (full implementation in 3.2, 3.3)

  """
  def intrinsic_size(%Widget{type: :label, props: props}, _context) do
    text = Keyword.get(props, :text, "")
    text_width = estimate_text_width(text)
    text_height = estimate_text_height(text)
    {:ok, %{width: text_width, height: text_height}}
  end

  def intrinsic_size(%Widget{type: :button, props: props}, _context) do
    text = Keyword.get(props, :text, "")
    text_width = estimate_text_width(text)
    text_height = estimate_text_height(text)

    # Button has padding around the text
    {pad_width, pad_height} = button_padding()

    {:ok, %{
      width: text_width + pad_width,
      height: text_height + pad_height
    }}
  end

  def intrinsic_size(%Widget{type: :container, props: props, children: children}, context) when is_list(children) do
    layout_type = Keyword.get(props, :layout)

    case layout_type do
      :vbox ->
        vbox_intrinsic_size(children, props, context)

      :hbox ->
        hbox_intrinsic_size(children, props, context)

      _ ->
        # Fallback for untyped containers
        container_intrinsic_size(children, context)
    end
  end

  def intrinsic_size(%Widget{type: :container, children: []}, _context) do
    {:ok, %{width: 0, height: 0}}
  end

  # VBox intrinsic size calculation
  defp vbox_intrinsic_size(children, props, context) do
    box_props = Box.extract_props(props)
    child_intrinsic_sizes = Box.child_intrinsic_sizes(children, context)

    # Calculate intrinsic container size
    max_child_width = Enum.reduce(child_intrinsic_sizes, 0, fn size, acc -> max(acc, size.width) end)
    total_child_height = Enum.reduce(child_intrinsic_sizes, 0, fn size, acc -> acc + size.height end)
    spacing_height = box_props.spacing * max(length(children) - 1, 0)

    intrinsic_width = max_child_width + box_props.padding_total
    intrinsic_height = total_child_height + spacing_height + box_props.padding_total

    {:ok, %{width: intrinsic_width, height: intrinsic_height}}
  end

  # HBox intrinsic size calculation
  defp hbox_intrinsic_size(children, props, context) do
    box_props = Box.extract_props(props)
    child_intrinsic_sizes = Box.child_intrinsic_sizes(children, context)

    # Calculate intrinsic container size (swapped width/height from VBox)
    total_child_width = Enum.reduce(child_intrinsic_sizes, 0, fn size, acc -> acc + size.width end)
    max_child_height = Enum.reduce(child_intrinsic_sizes, 0, fn size, acc -> max(acc, size.height) end)
    spacing_width = box_props.spacing * max(length(children) - 1, 0)

    intrinsic_width = total_child_width + spacing_width + box_props.padding_total
    intrinsic_height = max_child_height + box_props.padding_total

    {:ok, %{width: intrinsic_width, height: intrinsic_height}}
  end

  # Constraint Application

  @doc """
  Applies size constraints to a calculated size.

  Returns the final size after applying:
  1. Fixed size (if specified, overrides everything)
  2. Min/max constraints (clamps size)
  3. Available bounds (clamps to available space)

  """
  def apply_constraints(size, constraints, available_bounds) do
    width = apply_width_constraints(size.width, constraints, available_bounds.width)
    height = apply_height_constraints(size.height, constraints, available_bounds.height)

    if width > 0 and height > 0 do
      {:ok, %{width: width, height: height}}
    else
      {:error, "Calculated size is invalid: width=#{width}, height=#{height}"}
    end
  end

  defp apply_width_constraints(intrinsic_width, constraints, available_width) do
    cond do
      # Fixed width overrides everything
      Map.has_key?(constraints, :fixed_width) ->
        constraints.fixed_width

      # Clamp to min/max bounds
      true ->
        min_width = Map.get(constraints, :min_width, 1)
        max_width = Map.get(constraints, :max_width, available_width)
        max_width = if max_width == :infinity, do: available_width, else: max_width

        intrinsic_width
        |> max(min_width)
        |> min(max_width)
        |> min(available_width)
    end
  end

  defp apply_height_constraints(intrinsic_height, constraints, available_height) do
    cond do
      # Fixed height overrides everything
      Map.has_key?(constraints, :fixed_height) ->
        constraints.fixed_height

      # Clamp to min/max bounds
      true ->
        min_height = Map.get(constraints, :min_height, 1)
        max_height = Map.get(constraints, :max_height, available_height)
        max_height = if max_height == :infinity, do: available_height, else: max_height

        intrinsic_height
        |> max(min_height)
        |> min(max_height)
        |> min(available_height)
    end
  end

  # Position Calculation

  defp calculate_position(%Widget{}, _size, %Context{} = context) do
    # For leaf widgets, position is at parent's origin
    # Containers will handle child positioning in sections 3.2 and 3.3
    {:ok, %{
      x: Context.parent_x(context),
      y: Context.parent_y(context)
    }}
  end

  # Container Intrinsic Size (placeholder)

  defp container_intrinsic_size(children, _context) when is_list(children) do
    # Simplified intrinsic size for containers
    # Full implementation in sections 3.2 and 3.3
    if children == [] do
      {:ok, %{width: 0, height: 0}}
    else
      # For now, return max of children's intrinsic sizes
      # This will be properly calculated in VBox/HBox implementations
      {max_width, max_height} =
        Enum.reduce(children, {0, 0}, fn child, {max_w, max_h} ->
          case intrinsic_size(child, %Context{}) do
            {:ok, %{width: w, height: h}} ->
              {max(max_w, w), max(max_h, h)}
            _ ->
              {max_w, max_h}
          end
        end)

      {:ok, %{width: max_width, height: max_height}}
    end
  end

  # Widget Constraint Extraction

  @doc """
  Extracts size-related props from a widget and converts them to layout constraints.

  This allows widgets to override their intrinsic size with explicit dimensions
  or request flexible sizing via the expand prop.

  ## Widget Props to Constraints Mapping

  | Widget Prop  | Context Constraint | Notes                           |
  |-------------|-------------------|---------------------------------|
  | `:width`    | `:fixed_width`    | Exact pixel width               |
  | `:height`   | `:fixed_height`   | Exact pixel height              |
  | `:min_width`| `:min_width`      | Minimum width in pixels         |
  | `:min_height`| `:min_height`    | Minimum height in pixels        |
  | `:max_width`| `:max_width`      | Maximum width (or :infinity)    |
  | `:max_height`| `:max_height`    | Maximum height (or :infinity)   |
  | `:expand`   | Sets fixed size   | :width, :height, or true        |

  ## Expand Prop

  The `:expand` prop allows widgets to fill available space:

  * `:width` - Expand horizontally to fill available width
  * `:height` - Expand vertically to fill available height
  * `true` - Expand in both directions
  * `false` or nil - No expansion (default)

  ## Examples

      iex> widget = Widget.label("Hello", width: 100, height: 50)
      iex> Calculate.extract_widget_constraints(widget, %{width: 800, height: 600})
      %{fixed_width: 100, fixed_height: 50}

      iex> widget = Widget.button("Click", :click, expand: :width)
      iex> Calculate.extract_widget_constraints(widget, %{width: 800, height: 600})
      %{fixed_width: 800, max_width: 800}

  """
  def extract_widget_constraints(%Widget{props: props}, available_bounds) do
    fixed_width = Keyword.get(props, :width)
    fixed_height = Keyword.get(props, :height)
    min_width = Keyword.get(props, :min_width)
    min_height = Keyword.get(props, :min_height)
    max_width = Keyword.get(props, :max_width)
    max_height = Keyword.get(props, :max_height)
    expand = Keyword.get(props, :expand, false)

    # Handle expand prop - sets fixed size to available space
    {fixed_width, max_width} = case expand do
      :width -> {available_bounds.width, available_bounds.width}
      :height -> {fixed_width, max_width}
      true -> {available_bounds.width, available_bounds.width}
      false -> {fixed_width, max_width}
      nil -> {fixed_width, max_width}
    end

    {fixed_height, max_height} = case expand do
      :width -> {fixed_height, max_height}
      :height -> {available_bounds.height, available_bounds.height}
      true -> {available_bounds.height, available_bounds.height}
      false -> {fixed_height, max_height}
      nil -> {fixed_height, max_height}
    end

    # Build constraints map, only including non-nil values
    # Note: Don't include :infinity values for max constraints
    %{}
    |> maybe_put_constraint(fixed_width, :fixed_width)
    |> maybe_put_constraint(fixed_height, :fixed_height)
    |> maybe_put_constraint(min_width, :min_width)
    |> maybe_put_constraint(min_height, :min_height)
    |> maybe_put_constraint(max_width, :max_width, :infinity)
    |> maybe_put_constraint(max_height, :max_height, :infinity)
  end

  defp maybe_put_constraint(constraints, nil, _key, _exclude), do: constraints
  defp maybe_put_constraint(constraints, value, key, exclude) do
    if value == exclude, do: constraints, else: Map.put(constraints, key, value)
  end

  defp maybe_put_constraint(constraints, nil, _key), do: constraints
  defp maybe_put_constraint(constraints, value, key), do: Map.put(constraints, key, value)

  # Context Normalization

  defp normalize_context(nil, available_bounds) do
    Context.new(available_bounds.width, available_bounds.height)
  end

  defp normalize_context(%Context{} = context, _available_bounds) do
    context
  end

  # Text Size Estimation

  # Constants for text size estimation
  # These are temporary; real text measurement comes later
  @char_width 8
  @char_height 16

  defp estimate_text_width(text) when is_binary(text) do
    # Estimate based on character count
    # Each character is approximately 8 pixels wide
    String.length(text) * @char_width
  end

  defp estimate_text_height(_text) do
    # Fixed height for single-line text
    @char_height
  end

  # Button Padding

  defp button_padding do
    # Buttons have padding around the text
    # 20px horizontal (10px each side)
    # 10px vertical (5px each side)
    {20, 10}
  end
end
