require! {
  'game/actors'
  'game/area/el-modify'
  'game/area/settings'
  'game/editor/Editor'
  'game/editor/EditorView'
  'game/editor/tutorial/Tutorial'
  'game/hints/HintController'
  'lib/dom/Mapper'
  'lib/lang/CSS'
  'lib/lang/html'
}

counter = 0

create-style = ->
  $ '<style></style>'
    ..append-to document.head

module.exports = class AreaLevel extends Backbone.View
  class-name: 'area-level'
  id: -> _.unique-id 'arealevel-'

  initialize: ({level, stage}) ->
    @level = level
    @save-stage = stage
    @save-level = stage.scope-level level.url
    conf = @conf = settings.find level.$el
    conf <<< level.{x, y}

    @mapper = new Mapper @el

    @targets-to-actors!
    @style = create-style!
    html = @save-level.get \state.code.html or conf.html
    @set-HTML-CSS html, conf.css

    if conf.has-tutorial
      @tutorial = new Tutorial conf.tutorial

  render: ->
    @$el.css {
      width: @conf.width
      height: @conf.height
      top: @conf.y
      left: @conf.x
    }

  setup: ->
    # @targets-to-actors!
    @add-actors!

  remove: ->
    @hint-controller.destroy!
    if @tutorial then @tutorial.destroy!
    super!

  activate: ->
    @hint-controller ?= new HintController hints: @conf.hints, scope: @$el, store: @save-level
    @hint-controller.activate!

  deactivate: ->
    if @hint-controller then @hint-controller.deactivate!

  hide: ->
    @$el.add-class 'hidden'

  show: ->
    @$el.remove-class 'hidden'

  add-hidden: ->
    @$el.append @conf.hidden.add-class 'entity'

  targets-to-actors: ->
    targets = @conf.targets
      .map ({x, y}, i) ~> {x, y, id: "#{@level.url.replace /[^a-zA-Z0-9]/g ''}##{i}", level: @save-level.id}
      |> reject ({id}) ~> (@save-level.get 'state.kittens' or {})[id]
      |> map (target) ~>
        $ """
          <div class="entity-target" data-actor="kitten-box #{target.x} #{target.y} #{target.id}"></div>
        """

    for target in targets => @conf.hidden .= add target

  add-actors: ->
    @actors ?= for actor-el in @$ '[data-actor]' => actors.from-el actor-el, @conf.{x, y}, @save-level

  add-borders: (nodes) ->
    const thickness = 30px
    {width, height, x, y, borders, border-contract} = @conf

    if \top in borders
      nodes[*] = {
        type: \rect, id: \BORDER_TOP
        width: width, height: thickness
        x: x + width/2, y: y - thickness/2 + border-contract
      }

    if \left in borders
      nodes[*] = {
        type: \rect, id: \BORDER_LEFT
        width: thickness, height: height
        x: x - thickness/2 + border-contract, y: y + height/2
      }

    if \bottom in borders
      nodes[*] = {
        type: \rect, id: \BORDER_BOTTOM
        width: width, height: thickness
        x: x + width/2, y: y + height + thickness/2 - border-contract
      }

    if \right in borders
      nodes[*] = {
        type: \rect, id: \BORDER_RIGHT
        width: thickness, height: height
        x: x + width + thickness/2 - border-contract, y: y + height/2
      }

  redraw-from: (html, css) ->
    entities = @$el.children '.entity' .detach!
    @set-HTML-CSS html, css
    entities.append-to @$el

  set-HTML-CSS: (html-src, css-src) ->
    @current-HTML = html-src
    @current-CSS = css-src

    parsed = html.to-dom html-src
    @$el.empty!.append parsed.document
    @add-hidden!

    @$el.find 'style' .each (i, style) ~>
      $style = $ style
      $style.text! |> @preprocess-css |> $style.text

    @add-el-ids!
    css-src |> @preprocess-css |> @style.text

    @set-error parsed.error

  set-error: (error) ->
    if error?
      @$el.add-class 'has-errors'
    else
      @$el.remove-class 'has-errors'

  add-el-ids: ->
    @$ '[data-exit]' .attr 'data-id', 'ENTITY_EXIT'

  create-map: ~>
    el-modify @$el
    @mapper.build!
    @map = @mapper.map
    @add-borders @map
    @map = @map ++ @actors
    @map

  preprocess-css: (source) ->
    css = new CSS source
      ..scope \# + @el.id
      ..rewrite-hover '.PLAYER_CONTACT'

    css.to-string!

  start-editor: ->
    if @conf.has-tutorial then $ document.body .add-class 'has-tutorial'
    editor = new Editor {
      renderer: this
      original-HTML: @conf.html
      original-CSS: @conf.css
    }

    editor-view = new EditorView model: editor, render-el: @$el, el: $ '#editor'
      ..render!

    if @tutorial then @tutorial.attach editor-view

    editor.once \save, ~> @stop-editor editor, editor-view

  stop-editor: (editor, editor-view) ->
    if @tutorial then @tutorial.detach!
    $ document.body .remove-class 'has-tutorial'
    editor-view.restore-entities!
    editor-view.remove!
    @save-level.patch-state code: html: editor.get \html
    @redraw-from (editor.get \html), (editor.get \css)

    @trigger 'stop-editor'

  contains: (x, y) ->
    @conf.x < x < @conf.x + @conf.width and @conf.y < y < @conf.y + @conf.height
