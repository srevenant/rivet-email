defmodule Rivet.Email.EvalTemplateTest do
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
    assert {:error, {%{message: msg}, _}} =
             Rivet.Email.Test.Template.eval(@template <> "<%= bad ", "nobody@example.com", %{
               something: "reset"
             })

    # depending on the elixir version the message is different
    assert msg =~ ~r/expected closing/ or msg =~ ~r/missing token/

    assert {:error, {%{file: "nofile", description: "syntax error: expression is incomplete"}, _}} =
             Rivet.Email.Test.Template.eval(@template <> "<%= ! %> ", "nobody@example.com", %{
               something: "reset"
             })
  end
end
