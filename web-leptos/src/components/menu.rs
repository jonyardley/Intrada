use icondata;
use leptos::prelude::*;
use thaw::*;

#[component]
pub fn nav() -> impl IntoView {
    view! {
        <Flex>
            <NavDrawer>
                <NavItem
                    icon=icondata::AiLineChartOutlined
                    value="dashboard"
                    href="/"
                    attr:style="width: auto;"
                >
                    "Dashboard"
                </NavItem>
                <NavItem
                    icon=icondata::AiAimOutlined
                    value="goals"
                    href="/goals"
                    attr:style="width: auto;"
                >
                    "Goals"
                </NavItem>
                <NavItem
                    icon=icondata::AiClockCircleOutlined
                    value="sessions"
                    href="/sessions"
                    attr:style="width: auto;"
                >
                    "Sessions"
                </NavItem>
                <NavItem
                    icon=icondata::FiMusic
                    value="exercises"
                    href="/exercises"
                    attr:style="width: auto;"
                >
                    "Exercises"
                </NavItem>
            </NavDrawer>
        </Flex>
    }
}
