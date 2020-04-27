" =====
" Goals
" =====

" translation for Goals


function! coqpit#goals#xml2strs(goals)
  let list = a:goals.child[0].child
  let nr_subgoals = len(list)

  if nr_subgoals == 0
    return s:unfocused2strs(a:goals)
  endif

  let plural = nr_subgoals == 1 ? '' : 's'

  let res = []

  let res += [nr_subgoals .. ' subgoal' .. plural]

  for idx in range(nr_subgoals)
    let goal = list[idx]
    " let id = goal.child[0].child[0]
    let hyps = map(goal.child[1].child, 'coqpit#xml#2str(v:val)')
    let ccl = coqpit#xml#2str(goal.child[2])

    if idx == 0
      let res += coqpit#goals#hyps2strs(hyps)
    endif

    let res += ['______________________________________(' .. (idx + 1) .. '/' .. nr_subgoals .. ')']
    let res += split(ccl, "\n")
  endfor

  return res
endfunction

function! s:unfocused2strs(goals)
  let list_pair_unfocused = a:goals.child[1].child

  let list_unfocused = []
  for el in list_pair_unfocused
    let list_unfocused += el.child[0].child
    let list_unfocused += el.child[1].child
  endfor
  let nr_unfocused = len(list_unfocused)

  if nr_unfocused == 0
    return s:shelves2strs(a:goals)
  endif

  let res = ['This subproof is complete, but there are some unfocused goals:', '']

  for idx in range(nr_unfocused)
    let goal = list_unfocused[idx]
    " let id = goal.child[0].child[0]
    " let hyps = map(goal.child[1].child, 'coqpit#xml#2str(v:val)')
    let ccl = coqpit#xml#2str(goal.child[2])

    let res += ['______________________________________(' .. (idx + 1) .. '/' .. nr_unfocused .. ')']
    let res += split(ccl, "\n")
  endfor

  res += ['']

  return res
endfunction

function! s:shelves2strs(goals)
  let list_shelves = a:goals.child[2].child
  let nr_shelves = len(list_shelves)

  if nr_shelves == 0
    return s:gaveup2strs(a:goals)
  endif


  let res = ['All the remaining goals are on the shelf:', '']

  for idx in range(nr_shelves)
    let goal = list_shelves[idx]
    " let id = goal.child[0].child[0]
    " let hyps = map(goal.child[1].child, 'coqpit#xml#2str(v:val)')
    let ccl = coqpit#xml#2str(goal.child[2])

    let res += split(ccl, "\n")
  endfor

  let res += ['']

  return res
endfunction

function! s:gaveup2strs(goals)
  let list_gaveup = a:goals.child[3].child
  let nr_gaveup = len(list_gaveup)
  if nr_gaveup == 0
    return ['No more subgoals.']
  endif

  let res = ['No more subgoals, but there are some goals you gave up:', '']

  for idx in range(nr_gaveup)
    let goal = list_gaveup[idx]
    " let id = goal.child[0].child[0]
    " let hyps = map(goal.child[1].child, 'coqpit#xml#2str(v:val)')
    let ccl = coqpit#xml#2str(goal.child[2])

    let res += split(ccl, "\n")
  endfor

  let res += ['', 'You need to go back and solve them.']

  return res
endfunction


function! coqpit#goals#hyps2strs(hyps)
  let res = []
  for hyp in a:hyps
    let res += split(hyp, "\n")
  endfor
  return res
endfunction
