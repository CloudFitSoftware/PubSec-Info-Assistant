// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

import { Outlet, NavLink } from "react-router-dom";
import openai from "../../assets/openai.svg";
import { WarningBanner } from "../../components/WarningBanner/WarningBanner";
import styles from "./Layout.module.css";
import { Title } from "../../components/Title/Title";
import { getFeatureFlags, GetFeatureFlagsResponse, getUserRole, GetRoleResponse } from "../../api";
import { useEffect, useState } from "react";

export const Layout = () => {
    const [featureFlags, setFeatureFlags] = useState<GetFeatureFlagsResponse | null>(null);
    const [fetchedUserRole, setFetchedUserRole] = useState<GetRoleResponse | null>(null);

    async function fetchFeatureFlags() {
        try {
            const fetchedFeatureFlags = await getFeatureFlags();
            setFeatureFlags(fetchedFeatureFlags);
        } catch (error) {
            console.log(error);
        }
    }

    async function fetchUserRole() {
        try {
            const role = await getUserRole();
            console.log("Fetched user role:", role);
            setFetchedUserRole(role);
        } catch (error) {
            console.log(error);
        }
    }

    useEffect(() => {
        fetchFeatureFlags();
        fetchUserRole();
    }, []);

    useEffect(() => {
        console.log("User role state updated:", fetchedUserRole);
    }, [fetchedUserRole]);

    // Check if both user and admin roles are false
    if (!fetchedUserRole?.USER && !fetchedUserRole?.ADMIN) {
        return (
            <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh', textAlign: 'center' }}>
                <p>You are not currently part of any security groups. Please contact your administrator.</p>
            </div>
        );
    }

    return (
        <div className={styles.layout}>
            <header className={styles.header} role={"banner"}>
                <WarningBanner />
                <div className={styles.headerContainer}>
                    <div className={styles.headerTitleContainer}>
                        <img src={openai} alt="Azure OpenAI" className={styles.headerLogo} />
                        <h3 className={styles.headerTitle}><Title /></h3>
                    </div>
                    <nav>
                        <ul className={styles.headerNavList}>
                            {(fetchedUserRole?.USER || fetchedUserRole?.ADMIN) && (
                                <li>
                                    <NavLink to="/" className={({ isActive }) => (isActive ? styles.headerNavPageLinkActive : styles.headerNavPageLink)}>
                                        Chat
                                    </NavLink>
                                </li>
                            )}
                            {fetchedUserRole?.ADMIN && (
                                <li className={styles.headerNavLeftMargin}>
                                    <NavLink to="/content" className={({ isActive }) => (isActive ? styles.headerNavPageLinkActive : styles.headerNavPageLink)}>
                                        Manage Content
                                    </NavLink>
                                </li>
                            )}
                            {featureFlags?.ENABLE_MATH_ASSISTANT &&
                                <li className={styles.headerNavLeftMargin}>
                                    <NavLink to="/tutor" className={({ isActive }) => (isActive ? styles.headerNavPageLinkActive : styles.headerNavPageLink)}>
                                    Math Assistant
                                    <br />  
                                    <p className={styles.centered}>(preview)</p>
                                    </NavLink>
                                </li>
                            }
                            {featureFlags?.ENABLE_TABULAR_DATA_ASSISTANT &&
                                <li className={styles.headerNavLeftMargin}>
                                    <NavLink to="/tda" className={({ isActive }) => (isActive ? styles.headerNavPageLinkActive : styles.headerNavPageLink)}>
                                    Tabular Data Assistant
                                    <br />  
                                    <p className={styles.centered}>(preview)</p>
                                    </NavLink>
                                    
                                      
                                </li>
                            }
                    </ul>
                    </nav>
                </div>
            </header>

            <Outlet />

            <footer>
                <WarningBanner />
            </footer>
        </div>
    );
};
