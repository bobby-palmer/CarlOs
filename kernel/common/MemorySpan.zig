start: usize,
end: usize,

pub fn len(self: *const @This()) usize {
    return self.end - self.start;
}
