const express = require('express');
const app = express();

app.get('/:type/:id/:extra?.json', (req, res) => {
    res.json({
        match: 'single',
        params: req.params,
        url: req.url
    });
});

app.use((req, res) => {
    res.status(404).json({ error: 'Not Found', url: req.url });
});

const server = app.listen(3456, async () => {
    console.log('Test server running on 3456');
    // Test cases
    const tests = [
        '/movie/myid/genre=Action.json', // With extra
        '/movie/myid.json',             // Without extra
    ];

    for (const t of tests) {
        try {
            const res = await fetch(`http://localhost:3456${t}`);
            const data = await res.json();
            console.log(`REQ: ${t} => STATUS: ${res.status} =>`, data);
        } catch (e) { console.error(e); }
    }
    server.close();
});
