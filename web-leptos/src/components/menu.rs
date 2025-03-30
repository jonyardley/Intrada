use icondata;
use leptos::prelude::*;
use thaw::*;

#[component]
pub fn nav() -> impl IntoView {
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
                    <NavCategoryItem slot icon=icondata::AiAimOutlined>
                        "Goals"
                    </NavCategoryItem>

                    <NavSubItem value="manage-goals" href="/goals">
                        "Manage Goals"
                    </NavSubItem>

                </NavCategory>
                <NavCategory value="sessions">
                    <NavCategoryItem slot icon=icondata::AiClockCircleOutlined>
                        "Sessions"
                    </NavCategoryItem>
                    <NavSubItem value="start-session" href="/sessions/new">
                        "Start a session"
                    </NavSubItem>
                    <NavSubItem value="manage-sessions" href="/sessions">
                        "Manage sessions"
                    </NavSubItem>
                </NavCategory>
                <NavCategory value="exercises">
                    <NavCategoryItem slot icon=icondata::FiMusic>
                        "Exercises"
                    </NavCategoryItem>
                    <NavSubItem value="manage-exercises" href="/exercises">
                        "Manage exercises"
                    </NavSubItem>
                </NavCategory>
            </NavDrawer>
        </Flex>
    }
}
