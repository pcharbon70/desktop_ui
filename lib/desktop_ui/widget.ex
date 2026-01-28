defmodule DesktopUI.Widget do
  @moduledoc """
  Declarative widget constructors for building UI trees.

  This module provides helper functions for creating widget data structures
  that describe UI elements. These are pure data structures—they describe
  what to render, not how to render it.

  The widget system follows the declarative UI pattern used in The Elm Architecture.
  Components return widget trees from their `view/1` function, and the renderer
  interprets these trees to produce actual graphics.

  ## Widget Structure

  All widgets share a common structure:

  * `:type` - Atom identifying the widget type (:label, :button, :container)
  * `:id` - Optional unique identifier for event targeting and debugging
  * `:props` - Keyword list of widget properties
  * `:children` - List of child widgets (for container types)

  ## Basic Widgets

  ### Label

  Creates a text display element:

      Widget.label("Hello, World!")

      Widget.label("Count: 42", id: :count_label)

  ### Button

  Creates a clickable button that sends a message when clicked:

      Widget.button("Click me", :clicked)

      Widget.button("Increment", :increment, id: :btn_inc)

  ### Container

  Creates a layout container that arranges children:

      # Vertical box (children stacked vertically)
      Widget.container(:vbox, [
        Widget.label("Title"),
        Widget.button("OK", :ok)
      ], spacing: 8, padding: 16)

      # Horizontal box (children arranged horizontally)
      Widget.container(:hbox, [
        Widget.button("Yes", :yes),
        Widget.button("No", :no)
      ], spacing: 4)

  ## Common Props

  All widgets support these optional size properties:

  * `:id` - Unique identifier atom for event targeting
  * `:width` - Exact width in pixels (overrides intrinsic size)
  * `:height` - Exact height in pixels (overrides intrinsic size)
  * `:min_width` - Minimum width in pixels
  * `:min_height` - Minimum height in pixels
  * `:max_width` - Maximum width in pixels (or `:infinity`)
  * `:max_height` - Maximum height in pixels (or `:infinity`)
  * `:expand` - Fill available space (`:width`, `:height`, or `true`)

  Containers additionally support:

  * `:spacing` - Space between children (integer, default: 0)
  * `:padding` - Internal padding (integer, default: 0)

  Labels additionally support:

  * `:text` - The text to display (string)

  Buttons additionally support:

  * `:text` - The button label (string)
  * `:on_click` - Message to send when clicked (any type)

  ## Nesting

  Widgets can be nested to create complex UIs:

      Widget.container(:vbox, [
        Widget.label("Counter Demo"),
        Widget.container(:hbox, [
          Widget.button("+", :increment),
          Widget.button("-", :decrement)
        ], spacing: 8),
        Widget.label("Current: 0", id: :counter_label)
      ], spacing: 16, padding: 8)

  ## Validation

  Use `validate/1` to check if a widget structure is valid:

      case Widget.validate(widget) do
        :ok -> :widget_is_valid
        {:error, reason} -> :widget_has_issues
      end

  """

  defstruct [:type, :id, :props, :children]

  @type widget_type :: :label | :button | :container
  @type props :: keyword()
  @type children :: [t()]

  @type t :: %__MODULE__{
          type: widget_type(),
          id: atom() | nil,
          props: props(),
          children: children()
        }

  # Public API

  @doc """
  Creates a label widget for displaying text.

  A label is a simple text display element. It does not respond to user input.

  ## Size Options

  * `:width` - Exact width in pixels (overrides intrinsic text width)
  * `:height` - Exact height in pixels (overrides intrinsic text height)
  * `:min_width` - Minimum width in pixels
  * `:min_height` - Minimum height in pixels
  * `:max_width` - Maximum width in pixels (or `:infinity`)
  * `:max_height` - Maximum height in pixels (or `:infinity`)
  * `:expand` - Fill available space (`:width`, `:height`, or `true`)

  ## Other Options

  * `:id` - Optional unique identifier (atom)

  ## Examples

      Widget.label("Hello")
      #=> %DesktopUI.Widget{type: :label, props: [text: "Hello"], ...}

      Widget.label("Count: 42", id: :label)

      Widget.label("Stretchy", expand: :width)

  """
  @spec label(String.t(), keyword()) :: t()
  def label(text, opts \\ []) do
    props =
      opts
      |> Keyword.put(:text, text)

    %__MODULE__{
      type: :label,
      id: Keyword.get(opts, :id),
      props: props,
      children: []
    }
  end

  @doc """
  Creates a button widget with an on_click handler.

  Buttons are interactive elements that send a message when clicked.

  ## Parameters

  * `text` - The button label text
  * `on_click` - The message to send when the button is clicked
  * `opts` - Optional keyword list of properties

  ## Size Options

  * `:width` - Exact width in pixels (overrides intrinsic text width + padding)
  * `:height` - Exact height in pixels (overrides intrinsic text height + padding)
  * `:min_width` - Minimum width in pixels
  * `:min_height` - Minimum height in pixels
  * `:max_width` - Maximum width in pixels (or `:infinity`)
  * `:max_height` - Maximum height in pixels (or `:infinity`)
  * `:expand` - Fill available space (`:width`, `:height`, or `true`)

  ## Other Options

  * `:id` - Optional unique identifier (atom)

  ## Examples

      Widget.button("Click me", :clicked)
      #=> %DesktopUI.Widget{type: :button, props: [text: "Click me", on_click: :clicked], ...}

      Widget.button("Increment", :increment, id: :btn_inc)

      Widget.button("Stretchy", :click, expand: :width)

  """
  @spec button(String.t(), any(), keyword()) :: t()
  def button(text, on_click, opts \\ []) do
    props =
      opts
      |> Keyword.put(:text, text)
      |> Keyword.put(:on_click, on_click)

    %__MODULE__{
      type: :button,
      id: Keyword.get(opts, :id),
      props: props,
      children: []
    }
  end

  @doc """
  Creates a container widget that arranges child widgets.

  Containers are layout elements that organize their children. The layout
  type determines how children are arranged.

  ## Parameters

  * `layout_type` - Either `:vbox` (vertical) or `:hbox` (horizontal)
  * `children` - List of child widgets
  * `opts` - Optional keyword list of properties

  ## Size Options

  * `:width` - Exact width in pixels (overrides intrinsic container width)
  * `:height` - Exact height in pixels (overrides intrinsic container height)
  * `:min_width` - Minimum width in pixels
  * `:min_height` - Minimum height in pixels
  * `:max_width` - Maximum width in pixels (or `:infinity`)
  * `:max_height` - Maximum height in pixels (or `:infinity`)
  * `:expand` - Fill available space (`:width`, `:height`, or `true`)

  ## Layout Options

  * `:spacing` - Space between children in pixels (default: 0)
  * `:padding` - Internal padding in pixels (default: 0)

  ## Other Options

  * `:id` - Optional unique identifier (atom)

  ## Examples

      # Vertical box
      Widget.container(:vbox, [
        Widget.label("Title"),
        Widget.button("OK", :ok)
      ], spacing: 8)

      # Horizontal box
      Widget.container(:hbox, [
        Widget.button("Yes", :yes),
        Widget.button("No", :no)
      ], spacing: 4, padding: 16)

      # Container that fills available space
      Widget.container(:vbox, children, expand: true)

  """
  @spec container(:vbox | :hbox, [t()], keyword()) :: t()
  def container(layout_type, children, opts \\ []) when layout_type in [:vbox, :hbox] do
    props =
      opts
      |> Keyword.put(:layout, layout_type)
      |> Keyword.put_new(:spacing, 0)
      |> Keyword.put_new(:padding, 0)

    %__MODULE__{
      type: :container,
      id: Keyword.get(opts, :id),
      props: props,
      children: children
    }
  end

  @doc """
  Validates a widget structure.

  Returns `:ok` if the widget is valid, or `{:error, reason}` if invalid.

  ## Validation Rules

  * All widgets must have a valid type (:label, :button, :container)
  * Labels must have a :text property
  * Buttons must have :text and :on_click properties
  * Containers must have a :layout property (:vbox or :hbox)
  * All children must be valid widgets

  ## Examples

      iex> alias DesktopUI.Widget
      iex> Widget.validate(Widget.label("Hello"))
      :ok

      iex> alias DesktopUI.Widget
      iex> Widget.validate(%Widget{type: :invalid, props: [], children: []})
      {:error, "invalid widget type: :invalid"}

  """
  @spec validate(t()) :: :ok | {:error, String.t()}
  def validate(%__MODULE__{} = widget) do
    with :ok <- validate_type(widget),
         :ok <- validate_props(widget),
         :ok <- validate_children(widget) do
      :ok
    end
  end

  def validate(_other), do: {:error, "Not a widget"}

  # Private Functions

  defp validate_type(%__MODULE__{type: type}) when type in [:label, :button, :container], do: :ok

  defp validate_type(%__MODULE__{type: type}),
    do: {:error, "invalid widget type: #{inspect(type)}"}

  defp validate_props(%__MODULE__{type: :label, props: props}) do
    if Keyword.has_key?(props, :text) and is_binary(props[:text]) do
      :ok
    else
      {:error, "label must have a :text property (string)"}
    end
  end

  defp validate_props(%__MODULE__{type: :button, props: props}) do
    has_text = Keyword.has_key?(props, :text) and is_binary(props[:text])
    has_on_click = Keyword.has_key?(props, :on_click)

    cond do
      not has_text ->
        {:error, "button must have a :text property (string)"}

      not has_on_click ->
        {:error, "button must have an :on_click property"}

      true ->
        :ok
    end
  end

  defp validate_props(%__MODULE__{type: :container, props: props}) do
    layout = Keyword.get(props, :layout)

    if layout in [:vbox, :hbox] do
      :ok
    else
      {:error, "container must have a :layout property (:vbox or :hbox)"}
    end
  end

  defp validate_children(%__MODULE__{children: children}) when is_list(children) do
    Enum.reduce_while(children, :ok, fn child, _acc ->
      case validate(child) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_children(_), do: {:error, "children must be a list"}
end
