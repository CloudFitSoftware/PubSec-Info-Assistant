// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

import React, { useEffect, useRef } from "react";
import { array, func } from "prop-types";
import styles from "./drop-zone.module.css";

const Banner = ({ onClick, onDrop }: { onClick: any; onDrop: any }) => {
  const handleDragOver = (ev: any) => {
    ev.preventDefault();
    ev.stopPropagation();
    ev.dataTransfer.dropEffect = "copy";
  };

  const handleDrop = (ev: any) => {
    ev.preventDefault();
    ev.stopPropagation();
    onDrop(ev);
  };

  return (
    <div
      className={styles.banner}
      onClick={onClick}
      onDragOver={handleDragOver}
      onDrop={handleDrop}
    >
      <span className={styles.banner_text}>Click to Add a folder</span>
      <span className={styles.banner_text}>Or</span>
      <span className={styles.banner_text}>Drag and Drop files or folders here</span>
    </div>
  );
};

const DropZone = ({
  onChange,
  accept = ["*"],
}: {
  onChange: any;
  accept: string[];
}) => {
  const inputRef = useRef<HTMLInputElement>(null);

  const handleClick = () => {
    inputRef.current?.click();
  };

  const handleFileChange = (ev: any) => {
    onChange(ev.target.files);
  };

  const handleDrop = async (ev: any) => {
    ev.preventDefault();
    ev.stopPropagation();

    const items = ev.dataTransfer.items;
    const files: File[] = [];

    const traverseDirectory = async (entry: any, path: string) => {
      return new Promise<void>((resolve) => {
        if (entry.isFile) {
          entry.file((file: File) => {
            files.push(new File([file], `${file.name}`, { type: file.type }));
            resolve();
          });
        } else if (entry.isDirectory) {
          const dirReader = entry.createReader();
          dirReader.readEntries(async (entries: any[]) => {
            for (const subEntry of entries) {
              await traverseDirectory(subEntry, `${path}/${entry.name}`);
            }
            resolve();
          });
        }
      });
    };

    const promises: Promise<void>[] = [];
    for (let i = 0; i < items.length; i++) {
      const entry = items[i].webkitGetAsEntry();
      if (entry) {
        promises.push(traverseDirectory(entry, ""));
      }
    }

    await Promise.all(promises);
    onChange(files);
  };

  useEffect(() => {
    if (inputRef.current) {
      inputRef.current.setAttribute("webkitdirectory", "true");
    }
  }, []);

  return (
    <div className={styles.wrapper}>
      <Banner onClick={handleClick} onDrop={handleDrop} />
      <input
        type="file"
        aria-label="add files or folders"
        className={styles.input}
        ref={inputRef}
        multiple
        onChange={handleFileChange}
        accept={accept.join(",")}
      />
    </div>
  );
};

DropZone.propTypes = {
  accept: array,
  onChange: func,
};

export { DropZone };
