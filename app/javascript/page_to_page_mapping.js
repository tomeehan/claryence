// import your page component
import RolePlaySessionsShow from './pages/RolePlaySessions/Show'
import CoachingSessionsShow from './pages/CoachingSessions/Show'

const pageIdentifierToPageComponent = {
  'role_play_sessions/show': RolePlaySessionsShow,
  'coaching_sessions/show': CoachingSessionsShow,
};

export { pageIdentifierToPageComponent }
