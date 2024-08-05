// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

import React, { useState } from "react";
import ReactDOM from "react-dom/client";
import { HashRouter, Routes, Route, Navigate  } from "react-router-dom";
import { initializeIcons } from "@fluentui/react";

import "./index.css";

import { Layout } from "./pages/layout/Layout";
import NoPage from "./pages/NoPage";
import Chat from "./pages/chat/Chat";
import Content from "./pages/content/Content";
import Tutor from "./pages/tutor/Tutor";
import { Tda } from "./pages/tda/Tda";
import { getUserRole, GetRoleResponse } from "./api";
import { useEffect } from "react";

initializeIcons();

export default function App() {
    const [fetchedUserRole, setFetchedUserRole] = useState<GetRoleResponse | null>(null);
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
        fetchUserRole();
    }, []);
    
    const [toggle, setToggle] = React.useState('Work');
    return (
        <HashRouter>
            <Routes>
                <Route path="/" element={<Layout />}>
                    <Route index element={<Chat />} />
                    {fetchedUserRole?.ADMIN ? (
                        <Route path="content" element={<Content />} />
                    ) : (
                        <Route path="content" element={<Navigate to="/" />} />
                    )}                    
                    <Route path="*" element={<NoPage />} />
                    <Route path="tutor" element={<Tutor />} />
                    <Route path="tda" element={<Tda folderPath={""} tags={[]} />} />
            </Route>
            </Routes>
        </HashRouter>    
    );
}

ReactDOM.createRoot(document.getElementById("root") as HTMLElement).render(
    <React.StrictMode>
        <App />
    </React.StrictMode>
);