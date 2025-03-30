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
                    <NavSubItem value="manage-goals" href="/goals">"Manage Goals"</NavSubItem>
=======
                    <NavSubItem value="goals" href="/goals">
                        "Manage Goals"
                    </NavSubItem>
>>>>>>> dabcf06 (Updated refs in menu)
                </NavCategory>
                <NavCategory value="sessions">
                    <NavCategoryItem slot icon=icondata::AiPieChartOutlined>
                        "Sessions"
                    </NavCategoryItem>
<<<<<<< HEAD
                    <NavSubItem value="start-session" href="/sessions/new">"Start a session"</NavSubItem>
                    <NavSubItem value="manage-sessions" href="/sessions">"Manage sessions"</NavSubItem>
=======
                    <NavSubItem value="sessions" href="/sessions/new">
                        "Start a session"
                    </NavSubItem>
                    <NavSubItem value="sessions" href="/sessions">
                        "Manage sessions"
                    </NavSubItem>
>>>>>>> dabcf06 (Updated refs in menu)
                </NavCategory>
                <NavCategory value="exercises">
                    <NavCategoryItem slot icon=icondata::AiAreaChartOutlined>
                        "Exercises"
                    </NavCategoryItem>
<<<<<<< HEAD
                    <NavSubItem value="manage-exercises" href="/exercises">"Manage exercises"</NavSubItem>
=======
                    <NavSubItem value="exercises" href="/exercises">
                        "Manage exercises"
                    </NavSubItem>
>>>>>>> dabcf06 (Updated refs in menu)
                </NavCategory>
            </NavDrawer>
        </Flex>
    }
}
