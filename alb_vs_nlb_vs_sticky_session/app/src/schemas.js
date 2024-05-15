import Joi from 'joi'

export const validateSchema = (schema) => {
    return (req, res, next) => {
        const {
            error
        } = schema.validate(req.body)
        if (error === undefined) {
            next()
        } else {
            res.status(400)
            res.send(error)
        }
    }
}

export const sessionSchema = Joi.object({
    firstName: Joi.string().alphanum().min(1).max(40).required(),
    lastName: Joi.string().alphanum().min(1).max(40).required(),
    address: Joi.string().min(10).max(40).required(),
    age: Joi.number().positive(),
})