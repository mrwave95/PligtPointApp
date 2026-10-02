import './style.css'
import { supabase } from './supabase'

const app = document.querySelector<HTMLDivElement>('#app')!

let currentUserId: string | null = null

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

    <h3>Cash-in activity</h3>
    <ul id="redemption-history"></ul>
  </section>

  <section id="chores-section" hidden>
    <h2>Available chores</h2>
    <div id="chores-list"></div>
  </section>

  <section id="history-section" hidden>
    <h2>Recent activity</h2>
    <ul id="history"></ul>
  </section>

  <section id="profile-section" hidden>
    <h2>User settings</h2>

    <p>
      Available points:
      <strong id="available-points">0</strong>
    </p>

    <div>
      <label for="profile-color">Your colour</label>
      <input
        id="profile-color"
        type="color"
        value="#8b5cf6"
      >

      <button id="save-color-button">
        Save colour
      </button>
    </div>

    <br>

    <button id="cash-in-button">
      Cash in all available points
    </button>
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

const redemptionHistory =
  document.querySelector<HTMLUListElement>('#redemption-history')!

const choresSection =
  document.querySelector<HTMLElement>('#chores-section')!

const choresList =
  document.querySelector<HTMLDivElement>('#chores-list')!

const historySection =
  document.querySelector<HTMLElement>('#history-section')!

const history =
  document.querySelector<HTMLUListElement>('#history')!

const profileSection =
  document.querySelector<HTMLElement>('#profile-section')!

const availablePoints =
  document.querySelector<HTMLElement>('#available-points')!

const profileColor =
  document.querySelector<HTMLInputElement>('#profile-color')!

const saveColorButton =
  document.querySelector<HTMLButtonElement>('#save-color-button')!

const cashInButton =
  document.querySelector<HTMLButtonElement>('#cash-in-button')!


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
      await loadProfile()
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
    history.textContent =
      `Could not load history: ${completionsError.message}`
    return
  }

  const { data: chores, error: choresError } =
    await supabase
      .from('chores')
      .select('id, name')

  if (choresError) {
    history.textContent =
      `Could not load chores: ${choresError.message}`
    return
  }

  const { data: profiles, error: profilesError } =
    await supabase
      .from('profiles')
      .select('id, display_name')

  if (profilesError) {
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
      .select('id, display_name, color')

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

    const name = document.createElement('span')
    name.textContent =
      profile?.display_name ?? 'Unknown user'

    if (profile?.color) {
      name.style.color = profile.color
    }

    item.appendChild(name)
    item.append(` — ${score} points`)

    leaderboard.appendChild(item)
  }

  await loadRedemptionHistory()
}


async function loadRedemptionHistory() {
  const { data: redemptions, error: redemptionError } =
    await supabase
      .from('redemptions')
      .select('user_id, points_redeemed, redeemed_at')
      .order('redeemed_at', { ascending: false })
      .limit(20)

  if (redemptionError) {
    redemptionHistory.textContent =
      `Could not load cash-ins: ${redemptionError.message}`
    return
  }

  const { data: profiles, error: profilesError } =
    await supabase
      .from('profiles')
      .select('id, display_name')

  if (profilesError) {
    redemptionHistory.textContent =
      `Could not load profiles: ${profilesError.message}`
    return
  }

  redemptionHistory.innerHTML = ''

  if (redemptions.length === 0) {
    const item = document.createElement('li')
    item.textContent = 'No points have been cashed in yet.'
    redemptionHistory.appendChild(item)
    return
  }

  for (const redemption of redemptions) {
    const profile = profiles.find(
      profile => profile.id === redemption.user_id
    )

    const item = document.createElement('li')

    item.textContent =
      `${profile?.display_name ?? 'Unknown user'} ` +
      `cashed in ${redemption.points_redeemed} points`

    redemptionHistory.appendChild(item)
  }
}


async function loadProfile() {
  if (!currentUserId) {
    return
  }

  const { data: profile, error: profileError } =
    await supabase
      .from('profiles')
      .select('display_name, color')
      .eq('id', currentUserId)
      .single()

  if (profileError) {
    status.textContent =
      `Could not load profile: ${profileError.message}`
    return
  }

  if (profile.color) {
    profileColor.value = profile.color
  }

  const { data: completions, error: completionsError } =
    await supabase
      .from('completions')
      .select('points_awarded')
      .eq('user_id', currentUserId)

  if (completionsError) {
    status.textContent =
      `Could not calculate points: ${completionsError.message}`
    return
  }

  const { data: redemptions, error: redemptionsError } =
    await supabase
      .from('redemptions')
      .select('points_redeemed')
      .eq('user_id', currentUserId)

  if (redemptionsError) {
    status.textContent =
      `Could not calculate redeemed points: ${redemptionsError.message}`
    return
  }

  const earned =
    completions.reduce(
      (sum, completion) =>
        sum + completion.points_awarded,
      0
    )

  const redeemed =
    redemptions.reduce(
      (sum, redemption) =>
        sum + redemption.points_redeemed,
      0
    )

  const available = earned - redeemed

  availablePoints.textContent = String(available)

  cashInButton.disabled = available <= 0
}


saveColorButton.addEventListener('click', async () => {
  saveColorButton.disabled = true

  const { error } = await supabase.rpc(
    'set_profile_color',
    {
      p_color: profileColor.value,
    }
  )

  saveColorButton.disabled = false

  if (error) {
    status.textContent =
      `Could not save colour: ${error.message}`
    return
  }

  status.textContent = 'Profile colour saved.'

  await loadLeaderboard()
})


cashInButton.addEventListener('click', async () => {
  cashInButton.disabled = true
  status.textContent = 'Cashing in points...'

  const { data, error } =
    await supabase.rpc('cash_in_points')

  if (error) {
    status.textContent =
      `Could not cash in points: ${error.message}`

    await loadProfile()
    return
  }

  status.textContent =
    `Successfully cashed in ${data} points.`

  await loadProfile()
  await loadLeaderboard()
})


async function showSignedInApp(
  userId: string,
  email: string
) {
  currentUserId = userId

  loginSection.hidden = true

  accountSection.hidden = false
  leaderboardSection.hidden = false
  choresSection.hidden = false
  historySection.hidden = false
  profileSection.hidden = false

  status.textContent = `Signed in as ${email}`

  await loadChores()
  await loadHistory()
  await loadLeaderboard()
  await loadProfile()
}


function showSignedOutApp() {
  currentUserId = null

  loginSection.hidden = false

  accountSection.hidden = true
  leaderboardSection.hidden = true
  choresSection.hidden = true
  historySection.hidden = true
  profileSection.hidden = true

  choresList.innerHTML = ''
  history.innerHTML = ''
  leaderboard.innerHTML = ''
  redemptionHistory.innerHTML = ''

  householdTotal.textContent = '0'
  availablePoints.textContent = '0'
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
    data.user.id,
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
      session.user.id,
      session.user.email ?? 'household member'
    )
  } else {
    showSignedOutApp()
  }
}


initializeApp()