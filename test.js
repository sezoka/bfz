
function search_seq(start, arr, seq) {
    let pos = start + seq.length - 1;
    outer: while (pos < arr.length) {
        let i = 0;
        while (i < seq.length) {
            if (seq[seq.length - i - 1] != arr[pos - i]) {
                pos += 1;
                continue outer;
            }
            i += 1;
        }
        return pos - seq.length + 1;
    }
    return arr.length;
}

console.log(search_seq(0, [1, 2, 3, 4, 5, 6], [4, 5, 6]));
