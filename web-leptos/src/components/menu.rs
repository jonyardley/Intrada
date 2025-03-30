use icondata;
use leptos::prelude::*;
use thaw::*;

#[component]
<<<<<<< HEAD
pub fn nav() -> impl IntoView {
=======
pub fn Nav() -> impl IntoView {
    //Start with all categories open
>>>>>>> dabcf06 (Updated refs in menu)
    let open_categories = RwSignal::new(vec![
        "goals".to_string(),
        "sessions".to_string(),
        "exercises".to_string(),
    ]);

    view! {
        <Flex>
            <NavDrawer open_categories=open_categories>
                <NavItem icon=icondata::AiLineChartOutlined value="dashboard" href="/">
                    "Dashboard"
                </NavItem>
                <NavCategory value="goals">
                    <NavCategoryItem slot icon=icondata::AiAreaChartOutlined>
                        "Goals"
                    </NavCategoryItem>
<<<<<<< HEAD
<<<<<<< HEAD
                    <NavSubItem value="manage-goals" href="/goals">"Manage Goals"</NavSubItem>
=======
                    <NavSubItem value="goals" href="/goals">
=======
                    <NavSubItem value="manage-goals" href="/goals">
>>>>>>> fc679eb (Add unique values to menu)
                        "Manage Goals"
                    </NavSubItem>
>>>>>>> dabcf06 (Updated refs in menu)
                </NavCategory>
                <NavCategory value="sessions">
                    <NavCategoryItem slot icon=icondata::AiPieChartOutlined>
                        "Sessions"
                    </NavCategoryItem>
<<<<<<< HEAD
<<<<<<< HEAD
                    <NavSubItem value="start-session" href="/sessions/new">"Start a session"</NavSubItem>
                    <NavSubItem value="manage-sessions" href="/sessions">"Manage sessions"</NavSubItem>
=======
                    <NavSubItem value="sessions" href="/sessions/new">
=======
                    <NavSubItem value="start-session" href="/sessions/new">
>>>>>>> fc679eb (Add unique values to menu)
                        "Start a session"
                    </NavSubItem>
                    <NavSubItem value="manage-sessions" href="/sessions">
                        "Manage sessions"
                    </NavSubItem>
>>>>>>> dabcf06 (Updated refs in menu)
                </NavCategory>
                <NavCategory value="exercises">
                    <NavCategoryItem slot icon=icondata::AiAreaChartOutlined>
                        "Exercises"
                    </NavCategoryItem>
<<<<<<< HEAD
<<<<<<< HEAD
                    <NavSubItem value="manage-exercises" href="/exercises">"Manage exercises"</NavSubItem>
=======
                    <NavSubItem value="exercises" href="/exercises">
=======
                    <NavSubItem value="manage-exercises" href="/exercises">
>>>>>>> fc679eb (Add unique values to menu)
                        "Manage exercises"
                    </NavSubItem>
>>>>>>> dabcf06 (Updated refs in menu)
                </NavCategory>
            </NavDrawer>
        </Flex>
    }
}
