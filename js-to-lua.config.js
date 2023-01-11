module.exports = {
    lastSync: {
        ref: "d63d6e07c5b3cceab456c3d203dd7193ad4462dc",
        conversionToolVersion: "ef4bcc5c0d0fc3c5ca56cc84212d267b598f9de6"
    },
    upstream: {
        owner: "apollographql",
        repo: "apollo-client",
        primaryBranch: "main"
    },
    downstream: {
        owner: "roblox",
        repo: "apollo-client-lua",
        primaryBranch: "main",
        patterns: [
            "src/**/*.lua"
        ]
    },
    renameFiles: [
        [
            (filename) => filename.endsWith(".test.lua"),
            (filename) => filename.replace(".test.lua", ".spec.lua")
        ],
        [
            (filename) => filename.endsWith(".test.ts.lua"),
            (filename) => filename.replace(".test.ts.lua", ".spec.snap.lua")
        ],
        [
            (filename) => filename.endsWith(".ts.lua") && !filename.endsWith(".test.ts.lua"),
            (filename) => filename.replace(".ts.lua", ".spec.snap.lua")
        ],
        [
            (filename) => filename.includes('__tests__') && !filename.includes('.spec.')  && !filename.endsWith('index.lua'),
            (filename) => filename.replace('.lua', '.spec.lua')
        ],
        [
            (filename) => filename.endsWith(".snap.lua") && !filename.endsWith(".spec.snap.lua"),
            (filename) => filename.replace(".snap.lua", ".spec.snap.lua")
        ],
        [
            (filename) => filename.endsWith('index.lua'),
            (filename) => filename.replace('index.lua', 'init.lua')
        ],
        [
            (filename) => filename.endsWith('/__tests__/helpers.spec.lua'),
            (filename) => filename.replace('spec.lua', 'lua')
        ],
        [
            (filename) => filename.includes('src/core/__tests__/QueryManager/init.lua'),
            () => 'src/core/__tests__/QueryManager/init.roblox.spec.lua'
        ]
    ]
}