// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

import React, { useEffect, useState } from "react";
import { Example } from "./Example";
import styles from "./Example.module.css";
import { getExamplePrompts, GetExamplePromptResponse } from "../../api";

export type ExampleModel = {
    text: string;
    value: string;
};

interface Props {
    onExampleClicked: (value: string) => void;
}

export const ExampleList = ({ onExampleClicked }: Props) => {
    const [fetchedExamplePrompts, setExamplePrompts] = useState<ExampleModel[]>([]);

    useEffect(() => {
        async function fetchExamplePrompts() {
            try {
                const response = await getExamplePrompts();
                setExamplePrompts(response.PROMPTS);
            } catch (error) {
                console.log(error);
            }
        }

        fetchExamplePrompts();
    }, []);

    return (
        <ul className={styles.examplesNavList}>
            {fetchedExamplePrompts.map((x, i) => (
                <li key={i}>
                    <Example text={x.text} value={x.value} onClick={onExampleClicked} />
                </li>
            ))}
        </ul>
    );
};
