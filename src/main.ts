import './style.css'
import { supabase } from './supabase'

const app = document.querySelector<HTMLDivElement>('#app')!

app.innerHTML = `
  <h1>PligtPointApp</h1>

  <section id="login-section">
    <form id="login-form">
      <div>
        <label for="email">Email</label><br>
        <input id="email" type="email" required>
      </div>

      <div>
        <label for="password">Password</label><br>
        <input id="password" type="password" required>
      </div>

      <button type="submit">Sign in</button>
    </form>
  </section>

  <section id="account-section" hidden>
    <p id="status"></p>
    <button id="logout-button">Sign out</button>
  </section>

  <section id="leaderboard-section" hidden>
    <h2>Leaderboard</h2>

    <p>
      Household total:
      <strong id="household-total">0</strong>
      points
    </p>

    <ol id="leaderboard"></ol>
  </section>

  <section id="chores-section" hidden>
    <h2>Available chores</h2>
    <div id="chores-list"></div>
  </section>

  <section id="history-section" hidden>
    <h2>Recent activity</h2>
    <ul id="history"></ul>
  </section>
`

const loginSection =
  document.querySelector<HTMLElement>('#login-section')!

const form =
  document.querySelector<HTMLFormElement>('#login-form')!

const accountSection =
  document.querySelector<HTMLElement>('#account-section')!

const status =
  document.querySelector<HTMLParagraphElement>('#status')!

const logoutButton =
  document.querySelector<HTMLButtonElement>('#logout-button')!

const leaderboardSection =
  document.querySelector<HTMLElement>('#leaderboard-section')!

const householdTotal =
  document.querySelector<HTMLElement>('#household-total')!

const leaderboard =
  document.querySelector<HTMLOListElement>('#leaderboard')!

const choresSection =
  document.querySelector<HTMLElement>('#chores-section')!

const choresList =
  document.querySelector<HTMLDivElement>('#chores-list')!

const historySection =
  document.querySelector<HTMLElement>('#history-section')!

const history =
  document.querySelector<HTMLUListElement>('#history')!


async function loadChores() {
  const { data: chores, error } = await supabase
    .from('chores')
    .select('id, name, estimated_minutes, points')
    .eq('active', true)
    .order('name')

  if (error) {
    status.textContent =
      `Could not load chores: ${error.message}`
    return
  }

  choresList.innerHTML = ''

  for (const chore of chores) {
    const container = document.createElement('div')

    const title = document.createElement('strong')
    title.textContent = chore.name

    const details = document.createElement('p')
    details.textContent =
      `${chore.estimated_minutes ?? '?'} min — ${chore.points} points`

    const button = document.createElement('button')
    button.textContent = 'Complete'

    button.addEventListener('click', async () => {
      button.disabled = true
      status.textContent = `Completing ${chore.name}...`

      const { data, error } = await supabase.rpc(
        'complete_chore',
        {
          p_chore_id: chore.id,
        }
      )

      if (error) {
        status.textContent =
          `Completion failed: ${error.message}`

        button.disabled = false
        return
      }

      status.textContent =
        `${chore.name} completed. Completion ID: ${data}`

      button.disabled = false

      await loadHistory()
      await loadLeaderboard()
    })

    container.appendChild(title)
    container.appendChild(details)
    container.appendChild(button)

    choresList.appendChild(container)
  }
}


async function loadHistory() {
  const { data: completions, error: completionsError } =
    await supabase
      .from('completions')
      .select('*')
      .order('completed_at', { ascending: false })
      .limit(20)

  if (completionsError) {
    history.innerHTML = ''
    history.textContent =
      `Could not load history: ${completionsError.message}`
    return
  }

  const { data: chores, error: choresError } =
    await supabase
      .from('chores')
      .select('id, name')

  if (choresError) {
    history.innerHTML = ''
    history.textContent =
      `Could not load chores: ${choresError.message}`
    return
  }

  const { data: profiles, error: profilesError } =
    await supabase
      .from('profiles')
      .select('id, display_name')

  if (profilesError) {
    history.innerHTML = ''
    history.textContent =
      `Could not load profiles: ${profilesError.message}`
    return
  }

  history.innerHTML = ''

  for (const completion of completions) {
    const chore = chores.find(
      chore => chore.id === completion.chore_id
    )

    const profile = profiles.find(
      profile => profile.id === completion.user_id
    )

    const item = document.createElement('li')

    item.textContent =
      `${profile?.display_name ?? 'Unknown user'} — ` +
      `${chore?.name ?? 'Unknown chore'} — ` +
      `+${completion.points_awarded} points`

    history.appendChild(item)
  }
}


async function loadLeaderboard() {
  const { data: completions, error: completionsError } =
    await supabase
      .from('completions')
      .select('user_id, points_awarded')

  if (completionsError) {
    status.textContent =
      `Could not load leaderboard: ${completionsError.message}`
    return
  }

  const { data: profiles, error: profilesError } =
    await supabase
      .from('profiles')
      .select('id, display_name')

  if (profilesError) {
    status.textContent =
      `Could not load profiles: ${profilesError.message}`
    return
  }

  const scores = new Map<string, number>()
  let total = 0

  for (const completion of completions) {
    total += completion.points_awarded

    const currentScore =
      scores.get(completion.user_id) ?? 0

    scores.set(
      completion.user_id,
      currentScore + completion.points_awarded
    )
  }

  householdTotal.textContent = String(total)

  leaderboard.innerHTML = ''

  const sortedScores =
    [...scores.entries()]
      .sort((a, b) => b[1] - a[1])

  for (const [userId, score] of sortedScores) {
    const profile =
      profiles.find(profile => profile.id === userId)

    const item = document.createElement('li')

    item.textContent =
      `${profile?.display_name ?? 'Unknown user'} — ${score} points`

    leaderboard.appendChild(item)
  }
}


async function showSignedInApp(email: string) {
  loginSection.hidden = true

  accountSection.hidden = false
  leaderboardSection.hidden = false
  choresSection.hidden = false
  historySection.hidden = false

  status.textContent = `Signed in as ${email}`

  await loadChores()
  await loadHistory()
  await loadLeaderboard()
}


function showSignedOutApp() {
  loginSection.hidden = false

  accountSection.hidden = true
  leaderboardSection.hidden = true
  choresSection.hidden = true
  historySection.hidden = true

  choresList.innerHTML = ''
  history.innerHTML = ''
  leaderboard.innerHTML = ''

  householdTotal.textContent = '0'
}


form.addEventListener('submit', async (event) => {
  event.preventDefault()

  const email =
    document.querySelector<HTMLInputElement>('#email')!.value

  const passwordInput =
    document.querySelector<HTMLInputElement>('#password')!

  const password = passwordInput.value

  const submitButton =
    form.querySelector<HTMLButtonElement>('button')!

  submitButton.disabled = true
  submitButton.textContent = 'Signing in...'

  const { data, error } =
    await supabase.auth.signInWithPassword({
      email,
      password,
    })

  submitButton.disabled = false
  submitButton.textContent = 'Sign in'

  if (error) {
    alert(`Login failed: ${error.message}`)
    return
  }

  passwordInput.value = ''

  await showSignedInApp(
    data.user.email ?? 'household member'
  )
})


logoutButton.addEventListener('click', async () => {
  logoutButton.disabled = true

  const { error } = await supabase.auth.signOut()

  logoutButton.disabled = false

  if (error) {
    status.textContent =
      `Could not sign out: ${error.message}`
    return
  }

  showSignedOutApp()
})


async function initializeApp() {
  const {
    data: { session },
    error,
  } = await supabase.auth.getSession()

  if (error) {
    console.error('Could not read session:', error)
    showSignedOutApp()
    return
  }

  if (session) {
    await showSignedInApp(
      session.user.email ?? 'household member'
    )
  } else {
    showSignedOutApp()
  }
}


initializeApp()