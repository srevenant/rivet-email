defmodule Rivet.Email.TemplateTest do
  use ExUnit.Case

  doctest Rivet.Email.Template, import: true
  doctest Rivet.Email.Template.Helpers, import: true

  @template """
  === rivet-template-v1
  sections:
    subject: eex
    body: eex
  === subject
  <%= @email %> email
  === body
  <p>
  This is a message body for <%= @email %>
  """

  test "send via template" do
    assert {:ok, %{body: _, subject: "nobody@example.com email\n"}} =
             Rivet.Email.Test.Template.eval(@template, "nobody@example.com", %{something: "reset"})
  end

  test "handle bad" do
    # missing token '%>'"
    assert {:error,
            {%{
               message: "expected closing '%>' for EEx expression\n  |\n1 | <% import Elixir.Rivet.Email.Template.Helpers;import Transmogrify;import Transmogrify.As %><p>\n2 | This is a message body for <%= @email %>\n3 | <%= bad \n  | ^"
              # 1.14 :"missing token '%>'"
             },
             _}} =
             Rivet.Email.Test.Template.eval(@template <> "<%= bad ", "nobody@example.com", %{
               something: "reset"
             })

    assert {:error, {%{file: "nofile", description: "syntax error: expression is incomplete"}, _}} =
             Rivet.Email.Test.Template.eval(@template <> "<%= ! %> ", "nobody@example.com", %{
               something: "reset"
             })
  end
end
