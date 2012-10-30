window.SpiderChart = (src, target, options = {}) ->
  w = options.w or options.width  or 125
  h = options.h or options.height or 125
  margin = options.m or options.margin or 50

  chartHelper = 
    population:
      label: 'Initial Population'
    exclusions:
      label: 'Exclusion'
    exceptions:
      label: 'Exception'
    numerator:
      label: 'Numerator'
    denominator:
      label: 'Denominator'

  # translate 0 < i < sizeof(chartHelper) to angle
  angle = (i) -> i * (2*Math.PI / d3.keys(chartHelper).length) + Math.PI/2

  d3.json src, (json) ->
    chart = d3.select target
    measures = d3.nest().entries(json)
    outerRadius = d3.max measures.map((measure) -> d3.max(d3.keys(chartHelper), (key) -> measure[key]))

    qualityRange =
      simple: 10
      nominal: 20
      complex: 50
      untestable: 65
    color = (val) ->
      if val > qualityRange.untestable
        'untestable'
      else
        for cssClass, range of qualityRange
          return cssClass if val <= range

    DOMAIN_OFFSET = 10 # leave some empty space in the middle of radius DOMAIN_OFFSET
    _scale = d3.scale.linear().domain([0, qualityRange.untestable+DOMAIN_OFFSET]).range([0, h/2])
    scale = scale = (n) -> _scale(Math.min(n, qualityRange.untestable) + DOMAIN_OFFSET)
    scale[key] = prop for own key, prop of _scale
    line = d3.svg.line()
      .interpolate('cardinal-closed')
      .tension(0.75)
      .x (d, i) ->
        Math.cos(angle(i)) * scale(d)
      .y (d, i) ->
        -Math.sin(angle(i)) * scale(d)
      

    # does it make sense to use data(json).enter() ?
    # sort JSON by largest complexity score first
    for mData in json.sort((a, b) -> d3.max(d3.keys(chartHelper), (key) -> b[key]) - d3.max(d3.keys(chartHelper), (key) -> a[key]))
      # append header
      div = chart.append('div').attr('class','chart')
      # start in on svg
      parent = div.append('svg').attr('width', w+margin).attr('height', h+margin)
        .append('svg:g').attr('transform', "translate(#{(w+margin)/2}, #{(h+margin)/2})")

      parent.append('svg:circle').attr('r', scale(0)).attr('class', 'origin')
      for cssClass, range of qualityRange
        parent.append('svg:circle').attr('r', scale(range)).attr('class', "#{cssClass} bullseye")

      for n in d3.values(qualityRange)
        parent.append('svg:text').attr('class', 'bullseye-label')
          .attr('y', scale(n) - 2).attr('text-anchor', 'middle')
          .text(if n isnt qualityRange.untestable then n else '')

      # draw line across all data points
      nums = for key of chartHelper
        mData[key]
      parent.selectAll('path.spider')
        .data([nums]).enter()
        .append('svg:path')
        .attr('class', "spider #{color(d3.max(nums))}")
        .attr 'd', (d) -> "#{line(d)}Z"
      # iterate through axes
      for i, helper of d3.entries(chartHelper)
        i = parseInt i # remember, for some reason i is a character here, not an integer!
        group = parent.append('svg:g').attr('transform', "rotate(#{-(angle(i) * 180/Math.PI)})")
        # label
        group.append('svg:text').attr('class', "label").text(helper.value.label)
          .attr('x', h/2 + 13).attr('y', 0)
          .attr('text-anchor', 'middle')
          .attr 'transform', ->
            x = d3.select(@).attr 'x'
            y = d3.select(@).attr 'y'
            "rotate(#{if i in [2..3] then -90 else 90} #{x} #{y})"
        # draw axis
        group.call(d3.svg.axis().tickValues(0).tickSize(1).scale(scale))
        # circle
        group.append('svg:circle').attr('class', "#{helper.key} #{color(mData[helper.key])}").attr('r', 4)
          .attr('cx', scale(mData[helper.key])).attr('value', mData[helper.key])
        # values
        valueOffset = if mData[helper.key] <= qualityRange.complex
          12
        else if mData[helper.key] <= qualityRange.untestable
          -12
        else
         -21
        if mData[helper.key] > qualityRange.untestable
          rWidth = 30; rHeight = 20
          group.append('svg:rect').attr('class', color(mData[helper.key]))
            .attr('width', rWidth).attr('height', rHeight)
            .attr('rx', 5)
            .attr('x', scale(mData[helper.key]) + valueOffset - rWidth/2).attr('y', -rHeight/2)
            .attr 'transform', ->
              x = scale(mData[helper.key]) + valueOffset
              y = 0
              "rotate(#{angle(i) * 180 / Math.PI} #{x} #{y})"
        group.append('svg:text').attr('class', "value #{color(mData[helper.key])}").text(mData[helper.key])
          .attr('x', scale(mData[helper.key]) + valueOffset).attr('y', 0)
          .attr 'transform', (d) ->
            x = d3.select(@).attr 'x'
            y = d3.select(@).attr 'y'
            "rotate(#{angle(i) * 180 / Math.PI} #{x} #{y})"

      div.append('div').attr('class', 'id').text "NQF #{mData.id}:"
      div.append('div').attr('class', 'name').text mData.name

