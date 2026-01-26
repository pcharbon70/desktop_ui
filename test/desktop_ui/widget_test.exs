defmodule DesktopUI.WidgetTest do
  use ExUnit.Case, async: true
  doctest DesktopUI.Widget

  alias DesktopUI.Widget

  describe "Widget struct" do
    test "creates widget with all fields" do
      widget = %Widget{
        type: :label,
        id: :my_label,
        props: [text: "Hello"],
        children: []
      }

      assert widget.type == :label
      assert widget.id == :my_label
      assert widget.props == [text: "Hello"]
      assert widget.children == []
    end

    test "struct has proper fields" do
      # Verify the struct has the expected keys
      widget = %Widget{}
      assert Map.has_key?(widget, :type)
      assert Map.has_key?(widget, :id)
      assert Map.has_key?(widget, :props)
      assert Map.has_key?(widget, :children)
    end
  end

  describe "label/2" do
    test "creates a label widget with text" do
      widget = Widget.label("Hello, World!")

      assert widget.type == :label
      assert widget.props[:text] == "Hello, World!"
      assert widget.children == []
      assert widget.id == nil
    end

    test "creates a label with id option" do
      widget = Widget.label("Test", id: :test_label)

      assert widget.id == :test_label
      assert widget.props[:text] == "Test"
    end

    test "creates a label with width and height options" do
      widget = Widget.label("Size test", width: 100, height: 20)

      assert widget.props[:width] == 100
      assert widget.props[:height] == 20
      assert widget.props[:text] == "Size test"
    end

    test "label preserves all provided options in props" do
      widget = Widget.label("Full test", id: :lbl, width: 200, height: 25)

      assert widget.props[:text] == "Full test"
      assert widget.props[:id] == :lbl
      assert widget.props[:width] == 200
      assert widget.props[:height] == 25
    end

    test "multiple labels have different text values" do
      label1 = Widget.label("First")
      label2 = Widget.label("Second")

      assert label1.props[:text] == "First"
      assert label2.props[:text] == "Second"
    end
  end

  describe "button/3" do
    test "creates a button widget with text and on_click" do
      widget = Widget.button("Click me", :clicked)

      assert widget.type == :button
      assert widget.props[:text] == "Click me"
      assert widget.props[:on_click] == :clicked
      assert widget.children == []
      assert widget.id == nil
    end

    test "creates a button with id option" do
      widget = Widget.button("Submit", :submit_msg, id: :submit_btn)

      assert widget.id == :submit_btn
      assert widget.props[:text] == "Submit"
      assert widget.props[:on_click] == :submit_msg
    end

    test "creates a button with width and height options" do
      widget = Widget.button("Big", :big_click, width: 150, height: 50)

      assert widget.props[:width] == 150
      assert widget.props[:height] == 50
      assert widget.props[:text] == "Big"
      assert widget.props[:on_click] == :big_click
    end

    test "button on_click can be any message type" do
      atom_msg = Widget.button("Atom", :msg)
      tuple_msg = Widget.button("Tuple", {:complex, :message})
      map_msg = Widget.button("Map", %{event: :clicked})

      assert atom_msg.props[:on_click] == :msg
      assert tuple_msg.props[:on_click] == {:complex, :message}
      assert map_msg.props[:on_click] == %{event: :clicked}
    end
  end

  describe "container/3" do
    test "creates a vbox container with children" do
      children = [
        Widget.label("Child 1"),
        Widget.label("Child 2")
      ]

      widget = Widget.container(:vbox, children)

      assert widget.type == :container
      assert widget.props[:layout] == :vbox
      assert widget.children == children
    end

    test "creates an hbox container with children" do
      children = [
        Widget.button("A", :a),
        Widget.button("B", :b)
      ]

      widget = Widget.container(:hbox, children)

      assert widget.type == :container
      assert widget.props[:layout] == :hbox
      assert widget.children == children
    end

    test "container has default spacing of 0" do
      widget = Widget.container(:vbox, [Widget.label("Test")])

      assert widget.props[:spacing] == 0
    end

    test "container has default padding of 0" do
      widget = Widget.container(:vbox, [Widget.label("Test")])

      assert widget.props[:padding] == 0
    end

    test "container with custom spacing" do
      widget = Widget.container(:vbox, [], spacing: 16)

      assert widget.props[:spacing] == 16
    end

    test "container with custom padding" do
      widget = Widget.container(:hbox, [], padding: 12)

      assert widget.props[:padding] == 12
    end

    test "container with id option" do
      widget = Widget.container(:vbox, [], id: :main_container)

      assert widget.id == :main_container
    end

    test "container with width and height options" do
      widget = Widget.container(:hbox, [], width: 300, height: 200)

      assert widget.props[:width] == 300
      assert widget.props[:height] == 200
    end

    test "container with all options" do
      children = [Widget.label("Test")]
      widget = Widget.container(:vbox, children, id: :cont, spacing: 8, padding: 16, width: 100)

      assert widget.props[:layout] == :vbox
      assert widget.props[:spacing] == 8
      assert widget.props[:padding] == 16
      assert widget.props[:width] == 100
      assert widget.id == :cont
      assert widget.children == children
    end
  end

  describe "nested widgets" do
    test "supports nesting containers within containers" do
      inner_vbox = Widget.container(:vbox, [Widget.label("Inner")])
      outer_hbox = Widget.container(:hbox, [inner_vbox, Widget.label("Outer")])

      assert length(outer_hbox.children) == 2
      assert Enum.at(outer_hbox.children, 0).type == :container
      assert Enum.at(outer_hbox.children, 0).props[:layout] == :vbox
    end

    test "supports deeply nested widget trees" do
      deep_tree =
        Widget.container(:vbox, [
          Widget.container(:hbox, [
            Widget.container(:vbox, [
              Widget.label("Deep")
            ])
          ])
        ])

      # Navigate the tree
      level1 = Enum.at(deep_tree.children, 0)
      level2 = Enum.at(level1.children, 0)
      level3 = Enum.at(level2.children, 0)

      assert level1.props[:layout] == :hbox
      assert level2.props[:layout] == :vbox
      assert level3.type == :label
      assert level3.props[:text] == "Deep"
    end

    test "supports mixed widget types in container" do
      mixed =
        Widget.container(:vbox, [
          Widget.label("Title"),
          Widget.button("Click", :clicked),
          Widget.container(:hbox, [Widget.label("Nested")])
        ])

      assert length(mixed.children) == 3
      assert Enum.at(mixed.children, 0).type == :label
      assert Enum.at(mixed.children, 1).type == :button
      assert Enum.at(mixed.children, 2).type == :container
    end
  end

  describe "validate/1" do
    test "validates a correct label widget" do
      widget = Widget.label("Valid label")
      assert Widget.validate(widget) == :ok
    end

    test "validates a correct button widget" do
      widget = Widget.button("Click", :clicked)
      assert Widget.validate(widget) == :ok
    end

    test "validates a correct vbox container" do
      widget = Widget.container(:vbox, [Widget.label("Child")])
      assert Widget.validate(widget) == :ok
    end

    test "validates a correct hbox container" do
      widget = Widget.container(:hbox, [Widget.button("B", :b)])
      assert Widget.validate(widget) == :ok
    end

    test "rejects widget with invalid type" do
      invalid = %Widget{type: :invalid_type, props: [], children: []}
      assert {:error, "invalid widget type: :invalid_type"} = Widget.validate(invalid)
    end

    test "rejects label without text property" do
      no_text = %Widget{type: :label, props: [], children: []}
      assert {:error, "label must have a :text property (string)"} = Widget.validate(no_text)
    end

    test "rejects label with non-string text" do
      bad_text = %Widget{type: :label, props: [text: 123], children: []}
      assert {:error, "label must have a :text property (string)"} = Widget.validate(bad_text)
    end

    test "rejects button without text" do
      no_text = %Widget{type: :button, props: [on_click: :msg], children: []}
      assert {:error, "button must have a :text property (string)"} = Widget.validate(no_text)
    end

    test "rejects button without on_click" do
      no_click = %Widget{type: :button, props: [text: "Click"], children: []}
      assert {:error, "button must have an :on_click property"} = Widget.validate(no_click)
    end

    test "rejects container without layout" do
      no_layout = %Widget{type: :container, props: [], children: []}

      assert {:error, "container must have a :layout property (:vbox or :hbox)"} =
               Widget.validate(no_layout)
    end

    test "rejects container with invalid layout" do
      bad_layout = %Widget{type: :container, props: [layout: :grid], children: []}

      assert {:error, "container must have a :layout property (:vbox or :hbox)"} =
               Widget.validate(bad_layout)
    end

    test "rejects non-list children" do
      bad_children = %Widget{
        type: :container,
        props: [layout: :vbox],
        children: "not a list"
      }

      assert {:error, "children must be a list"} = Widget.validate(bad_children)
    end

    test "rejects invalid child widgets" do
      bad_child =
        Widget.container(:vbox, [
          Widget.label("Good"),
          %Widget{type: :bad, props: [], children: []}
        ])

      assert {:error, "invalid widget type: :bad"} = Widget.validate(bad_child)
    end

    test "validates complex nested widget tree" do
      complex =
        Widget.container(
          :vbox,
          [
            Widget.label("Title"),
            Widget.container(
              :hbox,
              [
                Widget.button("Yes", :yes),
                Widget.button("No", :no)
              ],
              spacing: 8
            ),
            Widget.label("Footer")
          ],
          spacing: 16,
          padding: 10
        )

      assert Widget.validate(complex) == :ok
    end

    test "rejects non-widget input" do
      assert {:error, "not a widget"} = Widget.validate("not a widget")
      assert {:error, "not a widget"} = Widget.validate(%{})
      assert {:error, "not a widget"} = Widget.validate(nil)
    end
  end

  describe "widget equality" do
    test "two labels with same text are equal" do
      label1 = Widget.label("Test")
      label2 = Widget.label("Test")

      assert label1 == label2
    end

    test "two labels with different text are not equal" do
      label1 = Widget.label("Test1")
      label2 = Widget.label("Test2")

      refute label1 == label2
    end

    test "widgets with different ids are not equal" do
      label1 = Widget.label("Test", id: :id1)
      label2 = Widget.label("Test", id: :id2)

      refute label1 == label2
    end

    test "two identical containers are equal" do
      children = [Widget.label("Child")]
      container1 = Widget.container(:vbox, children, spacing: 8)
      container2 = Widget.container(:vbox, children, spacing: 8)

      assert container1 == container2
    end

    test "containers with different layout are not equal" do
      children = [Widget.label("Child")]
      vbox = Widget.container(:vbox, children)
      hbox = Widget.container(:hbox, children)

      refute vbox == hbox
    end
  end

  describe "real-world widget tree examples" do
    test "creates a counter UI" do
      counter_ui =
        Widget.container(
          :vbox,
          [
            Widget.label("Counter Demo", id: :title),
            Widget.container(
              :hbox,
              [
                Widget.button("Increment", :increment),
                Widget.button("Decrement", :decrement)
              ],
              spacing: 8
            ),
            Widget.label("Count: 0", id: :count_label)
          ],
          spacing: 16,
          padding: 12
        )

      assert Widget.validate(counter_ui) == :ok
      assert counter_ui.type == :container
      assert counter_ui.props[:layout] == :vbox
      assert length(counter_ui.children) == 3
    end

    test "creates a form UI" do
      form_ui =
        Widget.container(
          :vbox,
          [
            Widget.label("User Registration"),
            Widget.label("Username:", id: :username_label),
            Widget.button("Submit", :submit, id: :submit_btn),
            Widget.button("Cancel", :cancel, id: :cancel_btn)
          ],
          spacing: 10,
          padding: 20
        )

      assert Widget.validate(form_ui) == :ok
    end

    test "creates a toolbar UI" do
      toolbar =
        Widget.container(
          :hbox,
          [
            Widget.button("New", :new),
            Widget.button("Open", :open),
            Widget.button("Save", :save),
            Widget.button("Quit", :quit)
          ],
          spacing: 4,
          padding: 8,
          id: :toolbar
        )

      assert Widget.validate(toolbar) == :ok
      assert toolbar.id == :toolbar
      assert length(toolbar.children) == 4
    end
  end
end
