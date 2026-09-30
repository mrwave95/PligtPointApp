import './style.css'
import { supabase } from './supabase'

const app = document.querySelector<HTMLDivElement>('#app')!

app.innerHTML = `
  <h1>Household Chores</h1>

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

  <p id="status">Not signed in</p>

  <button id="complete-button" hidden>
    Complete test chore
  </button>
`

const form = document.querySelector<HTMLFormElement>('#login-form')!
const status = document.querySelector<HTMLParagraphElement>('#status')!
const completeButton =
  document.querySelector<HTMLButtonElement>('#complete-button')!

form.addEventListener('submit', async (event) => {
  event.preventDefault()

  const email =
    document.querySelector<HTMLInputElement>('#email')!.value

  const password =
    document.querySelector<HTMLInputElement>('#password')!.value

  status.textContent = 'Signing in...'

  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password,
  })

  if (error) {
    status.textContent = `Login failed: ${error.message}`
    return
  }

  const { data: chores, error: choresError } = await supabase
    .from('chores')
    .select('*')

  if (choresError) {
    status.textContent =
      `Signed in, but chore read failed: ${choresError.message}`
    return
  }

  status.textContent =
    `Signed in as ${data.user.email} | Found ${chores.length} chore(s)`

  completeButton.hidden = false
})

completeButton.addEventListener('click', async () => {
  status.textContent = 'Completing chore...'

  const { data, error } = await supabase.rpc(
    'complete_chore',
    {
      p_chore_id: 1,
    }
  )

  if (error) {
    status.textContent = `Completion failed: ${error.message}`
    return
  }

  status.textContent =
    `Chore completed successfully. Completion ID: ${data}`
})