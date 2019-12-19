" =====
" Goals
" =====

" translation for Goals


function! coquille#goals#xml2strs(goals)
  let list = a:goals.child[0].child
  let nr_subgoals = len(list)

  if nr_subgoals == 0
    let list_hidden = a:goals.child[1].child
    let nr_subgoals_hidden = len(list_hidden)

    if nr_subgoals_hidden == 0
      return ['No more subgoals.']
    endif
    
    let res = ['This subproof is complete, but there are some unfocused goals:', '']

    let next = []
    for el in list_hidden
      let next += el.child[1].child
    endfor
    let nr_next = len(next)

    for idx in range(nr_next)
      let goal = next[idx]
      " let id = goal.child[0].child[0]
      " let hyps = map(goal.child[1].child, 'coquille#goals#richpp2str(v:val)')
      let ccl = coquille#goals#richpp2str(goal.child[2])
    
      let res += ['======================== ( ' .. (idx + 1) .. ' / ' .. nr_next .. ' )']
      let res += split(ccl, "\n")
    endfor

    res += ['']

    return res
  endif

  let plural = nr_subgoals == 1 ? '' : 's'

  let res = []

  let res += [nr_subgoals .. ' subgoal' .. plural, '']

  for idx in range(nr_subgoals)
    let goal = list[idx]
    " let id = goal.child[0].child[0]
    let hyps = map(goal.child[1].child, 'coquille#goals#richpp2str(v:val)')
    let ccl = coquille#goals#richpp2str(goal.child[2])

    if idx == 0
      let res += coquille#goals#hyps2strs(hyps)
    endif

    let res += ['']
    let res += ['======================== ( ' .. (idx + 1) .. ' / ' .. nr_subgoals .. ' )']
    let res += split(ccl, "\n")
    let res += ['']
  endfor

  return res
endfunction




function! coquille#goals#hyps2strs(hyps)
  let res = []
  for hyp in a:hyps
    let res += split(hyp, "\n")
  endfor
  return res
endfunction

function! coquille#goals#richpp2str(richpp)
  if type(a:richpp) == v:t_string
    return coquille#goals#unescape(a:richpp)
  endif

  let res = ''
  for el in a:richpp.child
    let res ..= coquille#goals#richpp2str(el)
  endfor

  return res
endfunction

function! coquille#goals#unescape(str) abort
  return a:str
    \->substitute('&nbsp;', ' ', 'g')
    \->substitute('&apos;', "'", 'g')
endfunction

